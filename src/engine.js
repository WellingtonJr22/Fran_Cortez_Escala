export const symbol = { T: 'T', F: 'F', V: 'V', pending: '—' };
export const utc = date => new Date(`${date}T12:00:00Z`);
export const iso = date => date.toISOString().slice(0, 10);
export function datesInMonth(month) {
  const [y, m] = month.split('-').map(Number);
  return Array.from({ length: new Date(Date.UTC(y, m, 0)).getUTCDate() }, (_, i) => `${month}-${String(i + 1).padStart(2, '0')}`);
}
function monday(date) {
  const d = utc(date); d.setUTCDate(d.getUTCDate() - (d.getUTCDay() + 6) % 7); return d;
}
export function ruleFor(employee, date, rules, memberships = []) {
  const membership = memberships.filter(m => m.employee_id === employee.id && m.effective_from <= date).sort((a,b) => b.effective_from.localeCompare(a.effective_from))[0];
  const group = membership ? membership.group_id : employee.group_id;
  const applicable = rules.filter(r => r.effective_from <= date);
  return applicable.filter(r => r.employee_id === employee.id).sort((a,b) => b.effective_from.localeCompare(a.effective_from))[0]
    || applicable.filter(r => !r.employee_id && r.group_id && r.group_id === group).sort((a,b) => b.effective_from.localeCompare(a.effective_from))[0];
}
export function statusFor(date, rule) {
  const day = utc(date).getUTCDay();
  if (day === 0) return 'F';
  if (!rule) return 'pending';
  if (rule.kind === 'fixed') return rule.weekdays.includes(day) ? 'F' : 'T';
  const weeks = Math.round((monday(date) - monday(rule.anchor_date)) / 604800000);
  const index = ((weeks % rule.weekdays.length) + rule.weekdays.length) % rule.weekdays.length;
  return day === rule.weekdays[index] ? 'F' : 'T';
}
export function generate(month, employees, rules, exceptions, groups, memberships = [], manual = false, vacations = []) {
  const days = datesInMonth(month);
  return employees.filter(e => e.active).map(e => ({ id: e.id, name: e.name, role: e.role, group: groups.find(g => g.id === e.group_id)?.name || 'Sem grupo', color: groups.find(g => g.id === e.group_id)?.color || '#e8e4da', cells: Object.fromEntries(days.map(d => [d, manual ? 'pending' : vacations.some(v => v.employee_id === e.id && v.start_date <= d && v.end_date >= d) ? 'V' : exceptions.find(x => x.employee_id === e.id && x.date === d)?.status || statusFor(d, ruleFor(e, d, rules, memberships))])) }));
}
export function differences(before = [], after = []) {
  const result = [];
  for (const row of after) for (const [date, value] of Object.entries(row.cells)) {
    const previous = before.find(r => r.id === row.id)?.cells[date];
    if (previous !== value) result.push({ name: row.name, date, before: previous || 'ausente', after: value });
  }
  for (const row of before) if (!after.some(r => r.id === row.id)) result.push({ name: row.name, date: 'Todas as datas', before: 'presente', after: 'removido' });
  return result;
}
export function conflicts(rows, month) {
  const issues = [];
  for (const row of rows) {
    const pending = Object.values(row.cells).filter(s => s === 'pending').length;
    if (pending) issues.push(`${row.name}: ${pending} dia(s) a confirmar.`);
    for (const date of datesInMonth(month)) if (utc(date).getUTCDay() === 0 && row.cells[date] === 'T') issues.push(`${row.name}: trabalho no domingo ${date.split('-').reverse().join('/')}.`);
  }
  if (!rows.length) issues.push('Nenhum profissional ativo na escala.');
  return issues;
}
