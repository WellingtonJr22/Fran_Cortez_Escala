import { jsPDF } from 'jspdf';
import { autoTable } from 'jspdf-autotable';
import { datesInMonth, symbol, utc } from './engine.js';
export function exportPDF(schedule) {
  const doc = new jsPDF({orientation:'landscape',format:'a3'});
  const dates = datesInMonth(schedule.month.slice(0,7));
  const rows = [...schedule.rows].sort((a,b) => a.group.localeCompare(b.group) || a.name.localeCompare(b.name));
  autoTable(doc, {
    startY: 34, margin:{top:34,bottom:20,left:12,right:12},
    head:[['Grupo / profissional', ...dates.map(d => `${d.slice(-2)}\n${['DOM','SEG','TER','QUA','QUI','SEX','SAB'][utc(d).getUTCDay()]}`)]],
    body: rows.map(r => [`${r.group}\n${r.name}`, ...dates.map(d => symbol[r.cells[d]])]),
    styles:{fontSize:8,cellPadding:3,halign:'center',lineWidth:.15,lineColor:[224,224,220]},
    headStyles:{fillColor:[24,62,54],textColor:255}, columnStyles:{0:{cellWidth:66,halign:'left'}},
    didParseCell: data => { if(data.section==='body') { const row=rows[data.row.index]; if(data.column.index===0) data.cell.styles.fillColor=row.color; else { const status=row.cells[dates[data.column.index-1]]; data.cell.styles.fillColor=status==='F' ? [237,218,220] : status==='T' ? [229,240,233] : [244,238,221]; }} },
    didDrawPage: () => { doc.setFontSize(22); doc.setTextColor(24,62,54); doc.text('FRAN CORTEZ SALON',12,16); doc.setFontSize(11); doc.text(`Escala ${schedule.month.slice(0,7).split('-').reverse().join('/')} | ${schedule.status==='draft'?'RASCUNHO':'CONFIRMADA'} | Revisao ${schedule.version}`,12,25); if(schedule.status==='draft'){doc.setFontSize(14);doc.setTextColor(170,100,70);doc.text('RASCUNHO',doc.internal.pageSize.getWidth()-45,16);} }
  });
  const pages = doc.getNumberOfPages();
  for(let i=1;i<=pages;i++){doc.setPage(i);doc.setTextColor(80);doc.setFontSize(9);doc.text('Legenda: T - Trabalha | F - Folga | - A confirmar',12,doc.internal.pageSize.getHeight()-10);doc.text(`Pagina ${i} de ${pages}`,doc.internal.pageSize.getWidth()-38,doc.internal.pageSize.getHeight()-10);}
  doc.save(`Fran-Cortez-${schedule.month.slice(0,7)}-${schedule.status}.pdf`);
}
