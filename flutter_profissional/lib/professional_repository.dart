import 'package:supabase_flutter/supabase_flutter.dart';

/// Live repository: use only with a dedicated Coach Flow Profissional Supabase project.
/// Ownership is enforced by RLS and cross-owner composite foreign keys.
class ProfessionalRepository {
  ProfessionalRepository(this.client);
  final SupabaseClient client;
  String get owner {
    final id=client.auth.currentUser?.id;
    if(id==null) throw StateError('Entre na sua conta para continuar.');
    return id;
  }

  Future<List<Map<String,dynamic>>> clients() async =>
    (await client.from('cf_clients').select('id,name,service,phone,status')
      .eq('owner_id',owner).order('name'))
      .map((row)=>Map<String,dynamic>.from(row)).toList();

  Future<void> saveClient({String? id,required String name,
    required String service,required String phone,required String status}) async {
    final data=<String,dynamic>{'name':name.trim(),'service':service.trim(),
      'phone':phone.trim(),'status':status};
    if(data['name']== '') throw ArgumentError('Informe o nome.');
    if(id==null){
      await client.from('cf_clients').insert({...data,'owner_id':owner});
    } else {
      await client.from('cf_clients').update(data).eq('id',id).eq('owner_id',owner);
    }
  }

  Future<void> deleteClient(String id) async =>
    client.from('cf_clients').delete().eq('id',id).eq('owner_id',owner);

  Future<List<Map<String,dynamic>>> appointments(DateTime from,DateTime to) async =>
    (await client.from('cf_appointments')
      .select('id,client_id,starts_at,status,charge,unit_price,note,cf_clients(name)')
      .eq('owner_id',owner)
      .gte('starts_at',from.toUtc().toIso8601String())
      .lt('starts_at',to.toUtc().toIso8601String())
      .order('starts_at'))
      .map((row)=>Map<String,dynamic>.from(row)).toList();

  Future<void> saveAppointment({String? id,required String clientId,
    required DateTime startsAt,required String status,required bool charge,
    required double unitPrice,String note=''}) async {
    final data=<String,dynamic>{'client_id':clientId,
      'starts_at':startsAt.toUtc().toIso8601String(),'status':status,
      'charge':charge,'unit_price':unitPrice,'note':note};
    if(id==null) {
      await client.from('cf_appointments').insert({...data,'owner_id':owner});
    } else {
      await client.from('cf_appointments').update(data).eq('id',id).eq('owner_id',owner);
    }
  }

  Future<List<Map<String,dynamic>>> monthlyBilling(DateTime month) async {
    final start=DateTime(month.year,month.month);
    final end=DateTime(month.year,month.month+1);
    final appointmentsForMonth=await appointments(start,end);
    final bills=(await client.from('cf_billing')
      .select('client_id,adjustment,paid_at').eq('owner_id',owner)
      .eq('period',start.toIso8601String().substring(0,10)));
    final byClient=<String,Map<String,dynamic>>{};
    for(final a in appointmentsForMonth) {
      final id=a['client_id'] as String;
      final row=byClient.putIfAbsent(id,()=>{'client_id':id,
        'client_name':(a['cf_clients'] as Map?)?['name']??'Cliente',
        'realizados':0,'total':0.0});
      if(a['status']=='Realizada'&&a['charge']==true){
        row['realizados']=(row['realizados'] as int)+1;
        row['total']=(row['total'] as double)+((a['unit_price'] as num).toDouble());
      }
    }
    for(final bill in bills){
      final id=bill['client_id'] as String;
      final row=byClient.putIfAbsent(id,()=>{'client_id':id,'client_name':'Cliente',
        'realizados':0,'total':0.0});
      row['total']=((row['total'] as double)+(bill['adjustment'] as num).toDouble())
        .clamp(0.0,double.infinity).toDouble();
      row['paid']=bill['paid_at']!=null;
    }
    return byClient.values.toList();
  }

  Future<void> setPayment(String clientId,DateTime month,bool paid) async {
    final period=DateTime(month.year,month.month).toIso8601String().substring(0,10);
    await client.from('cf_billing').upsert({
      'owner_id':owner,'client_id':clientId,'period':period,
      'paid_at':paid?DateTime.now().toUtc().toIso8601String():null,
    },onConflict:'owner_id,client_id,period');
  }
}
