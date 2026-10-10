import test from 'node:test';
import assert from 'node:assert/strict';
import { datesInMonth, differences, generate, statusFor } from '../src/engine.js';

test('alternancia continua não reinicia no mês', () => {
  const rule = { kind:'alternating', weekdays:[1,3], anchor_date:'2026-01-05' };
  assert.equal(statusFor('2026-01-05',rule),'F');
  assert.equal(statusFor('2026-01-07',rule),'T');
  assert.equal(statusFor('2026-02-02',rule),'F');
});
test('domingo é folga geral e diferenças são identificadas', () => {
  assert.equal(statusFor('2026-02-01',{kind:'fixed',weekdays:[1],anchor_date:'2026-01-01'}),'F');
  const a=[{id:'e',name:'A',cells:{'2026-01-01':'T'}}], b=[{id:'e',name:'A',cells:{'2026-01-01':'F'}}];
  assert.deepEqual(differences(a,b),[{name:'A',date:'2026-01-01',before:'T',after:'F'}]);
  assert.equal(datesInMonth('2026-02').length,28);
});
