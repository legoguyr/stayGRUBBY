"""Verify project Storage access before saving keys in the macOS login Keychain."""
import ctypes as c
import getpass
import hashlib
import hmac
import json
from pathlib import Path
import re
import subprocess
import sys
import warnings
from urllib.parse import quote

PROJECTS = {
    'source': 'lgjxbpycphhsswxoncmz',
    'target': 'ayjflxstqmnuoiphbyek',
}
BUCKETS = {'cooking-photos', 'profile-photos', 'recipe-photos', 'social-photos'}
MAX_BYTES = 2_097_152


class CheckFailure(Exception):
    """Only operator-safe messages belong in this exception."""


def curl_get(side, path, key=None):
    url = f'https://{PROJECTS[side]}.supabase.co/storage/v1/{path}'
    command = [
        '/usr/bin/curl', '-q', '--noproxy', '*', '--proto', '=https', '--silent',
        '--connect-timeout', '8', '--max-time', '20', '--max-filesize', str(MAX_BYTES),
        '--write-out', '%{http_code}\n%{content_type}', '--output', '-', url,
    ]
    header = b''
    if key is not None:
        command.extend(['--header', '@-'])
        header = f'apikey: {key}\n'.encode('ascii')
    try:
        result = subprocess.run(
            command, input=header, capture_output=True, timeout=23,
            env={'PATH': '/usr/bin:/bin'},
        )
    except subprocess.TimeoutExpired:
        raise CheckFailure(f'{side}: Storage network request timed out.') from None
    except OSError:
        raise CheckFailure(f'{side}: could not start the macOS HTTPS client.') from None
    if result.returncode:
        if result.returncode in {35, 51, 58, 59, 60, 77, 83, 90, 91}:
            raise CheckFailure(f'{side}: Storage TLS certificate or handshake check failed (curl {result.returncode}).')
        if result.returncode == 63:
            raise CheckFailure(f'{side}: Storage response exceeded the allowed size.')
        raise CheckFailure(f'{side}: Storage network request failed (curl {result.returncode}).')
    prefix, separator, content_type = result.stdout.rpartition(b'\n')
    if not separator or not re.fullmatch(rb'[0-9]{3}', prefix[-3:]):
        raise CheckFailure(f'{side}: malformed Storage HTTP response metadata.')
    return int(prefix[-3:]), content_type.split(b';', 1)[0].decode('ascii', 'replace'), prefix[:-3]


def storage_get(side, path, key, stage):
    status, mime, body = curl_get(side, path, key)
    if status == 200:
        return mime, body
    if status == 401:
        reason = 'credential rejected or expired'
    elif status == 403:
        reason = 'access forbidden'
    elif status == 404:
        reason = 'object missing or access concealed'
    elif status == 400 and stage == 'bucket authorization':
        reason = 'request rejected by the Storage gateway'
        try:
            error = json.loads(body)
            message = error.get('message', '') if isinstance(error, dict) else ''
            if isinstance(message, str) and 'api key' in message.lower():
                reason = 'API key rejected'
        except (ValueError, UnicodeError):
            pass
    else:
        reason = 'unexpected HTTP response'
    raise CheckFailure(f'{side}: {stage} failed, {reason} (HTTP {status}).')


def source_samples():
    path = (Path.home() / 'Library/Application Support/StayGrubby/MigrationAudit'
            / '2026-11-12/phase-2b-storage-preflight.json')
    try:
        audit = json.loads(path.read_text())
        if audit['project_ref'] != PROJECTS['source']:
            raise ValueError
        selected = {}
        for sample in audit['sample']:
            bucket = sample['bucket_id']
            if bucket in BUCKETS and sample['reason'] and bucket not in selected:
                if (not isinstance(sample['path'], str) or not sample['path']
                        or not isinstance(sample['bytes'], int) or not 0 < sample['bytes'] <= MAX_BYTES
                        or not re.fullmatch(r'[0-9a-f]{64}', sample['download_sha256'])):
                    raise ValueError
                selected[bucket] = sample
        if selected.keys() != BUCKETS:
            raise ValueError
        return selected
    except (OSError, ValueError, KeyError, TypeError):
        raise CheckFailure('source: private photo audit is unreadable, malformed, or missing bucket coverage.') from None


def verify(side, key):
    _, body = storage_get(side, 'bucket', key, 'bucket authorization')
    try:
        inventory = json.loads(body)
        if not isinstance(inventory, list):
            raise TypeError
        ids = {item['id'] for item in inventory}
    except (ValueError, KeyError, TypeError):
        raise CheckFailure(f'{side}: invalid Storage bucket inventory response.') from None
    if ids != (BUCKETS if side == 'source' else set()):
        raise CheckFailure(f'{side}: Storage bucket inventory differs from the checkpoint.')
    if side == 'target':
        return
    for bucket, sample in sorted(source_samples().items()):
        path = f'object/authenticated/{bucket}/' + quote(sample['path'], safe='/')
        mime, body = storage_get(side, path, key, f'{bucket} photo read')
        if mime != 'image/jpeg' or len(body) != sample['bytes']:
            raise CheckFailure(f'source: {bucket} sample MIME type or byte count differs from the audit.')
        if hashlib.sha256(body).hexdigest() != sample['download_sha256']:
            raise CheckFailure(f'source: {bucket} sample SHA-256 differs from the audit.')


def security_framework():
    security = c.CDLL('/System/Library/Frameworks/Security.framework/Security')
    foundation = c.CDLL('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
    security.SecKeychainOpen.argtypes = [c.c_char_p, c.POINTER(c.c_void_p)]
    security.SecKeychainOpen.restype = c.c_int32
    security.SecKeychainFindGenericPassword.argtypes = [
        c.c_void_p, c.c_uint32, c.c_char_p, c.c_uint32, c.c_char_p,
        c.POINTER(c.c_uint32), c.POINTER(c.c_void_p), c.POINTER(c.c_void_p),
    ]
    security.SecKeychainFindGenericPassword.restype = c.c_int32
    security.SecKeychainItemModifyAttributesAndData.argtypes = [
        c.c_void_p, c.c_void_p, c.c_uint32, c.c_char_p,
    ]
    security.SecKeychainItemModifyAttributesAndData.restype = c.c_int32
    foundation.CFRelease.argtypes = [c.c_void_p]
    foundation.CFRelease.restype = None
    return security, foundation


def checked(status, description):
    if status:
        raise CheckFailure(f'{description} (Keychain status {status}).')


def update_items(keys, check_only=False):
    try:
        security, foundation = security_framework()
    except (OSError, AttributeError):
        raise CheckFailure('Keychain: could not load the macOS Security framework.') from None
    keychain = c.c_void_p()
    items = {}
    path = Path.home() / 'Library/Keychains/login.keychain-db'
    checked(security.SecKeychainOpen(str(path).encode(), c.byref(keychain)),
            'Cannot open the login Keychain')
    try:
        for side, project in PROJECTS.items():
            service = f'staygrubby-{side}-storage'.encode()
            account = project.encode()
            item = c.c_void_p()
            checked(security.SecKeychainFindGenericPassword(
                keychain, len(service), service, len(account), account,
                None, None, c.byref(item),
            ), f'Cannot locate the {side} Storage item')
            items[side] = item
        if check_only:
            return
        for side, item in items.items():
            value = keys[side].encode()
            checked(security.SecKeychainItemModifyAttributesAndData(
                item, None, len(value), value,
            ), f'Cannot update the {side} Storage item')
            print(f'Saved the verified {side} Storage key in the login Keychain.', flush=True)
    finally:
        for item in items.values():
            foundation.CFRelease(item)
        foundation.CFRelease(keychain)


def main():
    if sys.argv[1:] == ['--check-network']:
        for side in PROJECTS:
            status, _, _ = curl_get(side, 'bucket')
            if status not in {400, 401, 403}:
                raise CheckFailure(f'{side}: anonymous Storage probe returned HTTP {status}.')
            print(f'{side}: HTTPS certificate and connection verified (anonymous HTTP {status}).')
        return
    if sys.argv[1:] == ['--verify-keychain']:
        for side, project in PROJECTS.items():
            try:
                result = subprocess.run(
                    ['/usr/bin/security', 'find-generic-password', '-a', project, '-s',
                     f'staygrubby-{side}-storage', '-w'],
                    capture_output=True, timeout=55,
                )
            except (OSError, subprocess.TimeoutExpired):
                raise CheckFailure(f'{side}: Keychain read failed or timed out.') from None
            key = result.stdout.decode('ascii', 'replace').strip()
            if result.returncode:
                raise CheckFailure(f'{side}: Keychain read failed or was denied.')
            if not re.fullmatch(r'sb_secret_[A-Za-z0-9_-]+', key):
                raise CheckFailure(f'{side}: saved Keychain item does not contain a valid Secret key format.')
            verify(side, key)
            print(f'{side}: saved Storage key passed authentication and inventory checks.')
        return
    if sys.argv[1:] == ['--check-items']:
        update_items({}, check_only=True)
        print('PASS both exact login Keychain items located without reading password data.')
        return
    if sys.argv[1:] or not sys.stdin.isatty():
        raise CheckFailure('Run this file directly in macOS Terminal.')
    warnings.simplefilter('error', getpass.GetPassWarning)
    keys = {}
    for side, ref in PROJECTS.items():
        print(f'Copy the replacement Secret key for the {side} project ({ref}).')
        key = getpass.getpass(f'Paste the {side} Supabase Secret key here (hidden): ').strip()
        if not re.fullmatch(r'sb_secret_[A-Za-z0-9_-]+', key):
            raise CheckFailure(f'{side}: input does not match the Supabase Secret key format.')
        if keys and hmac.compare_digest(key, keys['source']):
            raise CheckFailure('Source and target need distinct project keys.')
        verify(side, key)
        print(f'{side.capitalize()} Storage authentication and inventory checks passed.')
        keys[side] = key
    update_items(keys)


if __name__ == '__main__':
    try:
        main()
    except CheckFailure as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except getpass.GetPassWarning:
        print('Terminal: a hidden prompt was unavailable. Run this file in macOS Terminal.', file=sys.stderr)
        sys.exit(1)
    except (KeyboardInterrupt, EOFError):
        print('Cancelled.', file=sys.stderr)
        sys.exit(1)
    except Exception:
        print('Unexpected helper error. Contact Codex for a local diagnosis.', file=sys.stderr)
        sys.exit(1)
