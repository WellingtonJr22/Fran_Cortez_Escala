import { createClient } from '@supabase/supabase-js';
const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
export const supabase = url && key ? createClient(url, key) : null;
export async function query(table) { const { data, error } = await supabase.from(table).select('*'); if(error) throw error; return data; }
export async function rpc(name, args) { const { data, error } = await supabase.rpc(name, args); if(error) throw error; return data; }
export const demo = {
  groups: [{id:'g1', name:'Equipe A', color:'#eadcca'}, {id:'g2',name:'Equipe B',color:'#dce8e4'}],
  employees: [
    {id:'e1',name:'Ludmila',role:'Profissional',group_id:'g1',active:true},{id:'e2',name:'Miriam Pinto',role:'Profissional',group_id:'g1',active:true},{id:'e3',name:'Val',role:'Profissional',group_id:'g1',active:true},{id:'e4',name:'Rose',role:'Profissional',group_id:'g1',active:true},{id:'e5',name:'Vitória',role:'Nail design',group_id:'g1',active:true},{id:'e6',name:'Denise',role:'Profissional',group_id:'g1',active:true},{id:'e7',name:'Ana Luísa',role:'Profissional',group_id:'g1',active:true},
    {id:'e8',name:'Érica',role:'Profissional',group_id:'g2',active:true},{id:'e9',name:'Neia',role:'Profissional',group_id:'g2',active:true},{id:'e10',name:'Miriam Bueno',role:'Profissional',group_id:'g2',active:true},{id:'e11',name:'Ana Lorena',role:'Profissional',group_id:'g2',active:true},{id:'e12',name:'Sula',role:'Profissional',group_id:'g2',active:true},{id:'e13',name:'Wanessa',role:'Profissional',group_id:'g2',active:true},
    {id:'e14',name:'Duda',role:'Profissional',group_id:null,active:true},{id:'e15',name:'Thaty',role:'Profissional',group_id:null,active:true},{id:'e16',name:'Wriele',role:'Profissional',group_id:null,active:true},{id:'e17',name:'Claudia',role:'Profissional',group_id:null,active:true},
    {id:'e18',name:'Tai',role:'Nail design',group_id:null,active:true},{id:'e19',name:'Ana Paula',role:'Nail design',group_id:null,active:true},{id:'e20',name:'Samara',role:'Nail design',group_id:null,active:true},
    {id:'e21',name:'Marcos',role:'Cabeleireiro',group_id:null,active:true},{id:'e22',name:'Priscila',role:'Cabeleireira',group_id:null,active:true},{id:'e23',name:'Ronaldo',role:'Cabeleireiro',group_id:null,active:true},{id:'e24',name:'Katiele',role:'Cabeleireira',group_id:null,active:true},{id:'e25',name:'Carpediane',role:'Cabeleireira',group_id:null,active:true}
  ],
  rules: [{id:'r1',group_id:'g1',employee_id:null,kind:'alternating',weekdays:[1,3],anchor_date:'2026-01-05',effective_from:'2026-01-01'},{id:'r2',group_id:'g2',employee_id:null,kind:'alternating',weekdays:[3,1],anchor_date:'2026-01-05',effective_from:'2026-01-01'}],
  memberships:[], exceptions:[], schedules:[], audit_log:[]
};
