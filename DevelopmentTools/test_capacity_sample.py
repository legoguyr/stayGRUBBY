import os
import subprocess
import unittest
from unittest.mock import patch

from check_capacity_sample import check, evaluate


class CapacitySampleTests(unittest.TestCase):
    def test_health_warning_and_incident(self):
        self.assertEqual(evaluate('{"age_seconds": 20, "signals": {}}')[0], 0)
        self.assertEqual(evaluate('{"age_seconds": 20, "signals": {"wal_bytes": "warning"}}')[0], 1)
        for level in ("incident", "critical"):
            with self.subTest(level=level):
                self.assertEqual(
                    evaluate(f'{{"age_seconds": 20, "signals": {{"wal_bytes": "{level}"}}}}')[0], 2
                )

    def test_no_sample_or_stale_sample_cannot_look_healthy(self):
        for raw in ("", "[]", '{"age_seconds": 901, "signals": {}}',
                    '{"age_seconds": -1, "signals": {}}', '{"age_seconds": NaN, "signals": {}}',
                    '{"age_seconds": true, "signals": {}}', '{"age_seconds": 0, "signals": []}'):
            with self.subTest(raw=raw):
                self.assertEqual(evaluate(raw)[0], 3)

    def test_unknown_data_and_database_errors_are_redacted(self):
        secret = "private fixture"
        self.assertNotIn(secret, evaluate(f'{{"age_seconds": 0, "signals": {{"wal_bytes": "{secret}"}}}}')[1])
        with patch.dict(os.environ, {"PGSERVICE": "capacity-reader"}, clear=True):
            with patch("check_capacity_sample.subprocess.run", side_effect=subprocess.CalledProcessError(
                1, "psql", stderr=secret
            )):
                code, message = check()
                self.assertEqual(code, 3)
                self.assertNotIn(secret, message)

    def test_uses_only_bounded_read_only_query(self):
        good = subprocess.CompletedProcess([], 0, stdout='{"age_seconds": 1, "signals": {}}')
        with patch.dict(os.environ, {"PGSERVICE": "capacity-reader"}, clear=True):
            with patch("check_capacity_sample.subprocess.run", return_value=good) as run:
                self.assertEqual(check()[0], 0)
                command = run.call_args.args[0]
                self.assertIn("--no-password", command)
                self.assertIn("begin read only", command[-1])
                self.assertIn("statement_timeout", command[-1])
                self.assertEqual(run.call_args.kwargs["timeout"], 12)

    def test_requires_configured_service(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(check()[0], 3)


if __name__ == "__main__":
    unittest.main()
