import assert from 'node:assert/strict';

// Read-only prerequisite for the disposable HTTP rehearsal. The old image approval
// queue must be gone; immediate publishing and report-based moderation are required.
export async function verifyCurrentLocalSchema(db) {
 const result=await db.query(`select
  to_regclass('staygrubby.image_reviews') is null
  and to_regprocedure('api.image_access(text,text)') is not null
  and to_regprocedure('api.moderation_review(text,jsonb)') is not null as ready`);
 assert.equal(result.rows[0]?.ready,true,'Current report-based image migrations must be replayed');
}
