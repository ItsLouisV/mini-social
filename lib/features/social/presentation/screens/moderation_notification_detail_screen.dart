import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/toast_service.dart';
import '../../providers/follow_provider.dart';

class ModerationNotificationDetailScreen extends ConsumerStatefulWidget {
  final String notificationId;
  const ModerationNotificationDetailScreen({super.key,required this.notificationId});
  @override ConsumerState<ModerationNotificationDetailScreen> createState()=>_ModerationNotificationDetailScreenState();
}

class _ModerationNotificationDetailScreenState extends ConsumerState<ModerationNotificationDetailScreen>{
  Map<String,dynamic>? _detail;Object? _error;bool _loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{setState(()=>_loading=true);try{final value=await ref.read(socialRepositoryProvider).getModerationNotificationDetail(widget.notificationId);if(mounted)setState((){_detail=value;_error=null;});}catch(error){if(mounted)setState(()=>_error=error);}finally{if(mounted)setState(()=>_loading=false);}}
  String _decisionLabel(String? action)=>switch(action){'hide'=>'Nội dung đã bị ẩn','remove'=>'Nội dung đã bị gỡ','restore'=>'Nội dung được phép hiển thị','auto_block'=>'Nội dung bị hệ thống tự động ẩn','auto_shadow_limit'=>'Nội dung bị hạn chế phân phối',_=>'Đã xem xét nội dung'};

  Future<void> _openAppealSheet()async{
    const choices=['Tôi cho rằng nội dung không vi phạm','Quyết định chưa xem xét đầy đủ ngữ cảnh','Nội dung của tôi đã bị hiểu nhầm','Hình thức xử lý chưa phù hợp','Lý do khác'];
    final controller=TextEditingController();String? selected;bool submitting=false;
    final submitted=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,useSafeArea:true,showDragHandle:true,builder:(sheetContext)=>StatefulBuilder(builder:(context,setSheetState)=>Padding(padding:EdgeInsets.fromLTRB(20,0,20,MediaQuery.viewInsetsOf(context).bottom+20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Bạn muốn kháng cáo điều gì',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:6),Text('Chọn lý do phù hợp nhất và cung cấp thêm thông tin để đội ngũ xem xét.',style:Theme.of(context).textTheme.bodyMedium?.copyWith(color:Theme.of(context).hintColor)),const SizedBox(height:18),...choices.map((choice)=>RadioListTile<String>(contentPadding:EdgeInsets.zero,dense:true,title:Text(choice),value:choice,groupValue:selected,onChanged:(value)=>setSheetState(()=>selected=value))),const SizedBox(height:8),TextField(controller:controller,minLines:3,maxLines:5,maxLength:500,decoration:const InputDecoration(labelText:'Thông tin bổ sung',hintText:'Mô tả ngữ cảnh hoặc lý do bạn cho rằng quyết định chưa chính xác…',border:OutlineInputBorder())),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:submitting||selected==null?null:()async{final extra=controller.text.trim();final reason=extra.isEmpty?selected!:'${selected!}\n\n$extra';if(reason.length<10){ToastService.showWarning(sheetContext,'Lý do kháng cáo cần có ít nhất 10 ký tự.');return;}setSheetState(()=>submitting=true);try{await ref.read(socialRepositoryProvider).submitModerationAppeal(notificationId:widget.notificationId,reason:reason);if(sheetContext.mounted)Navigator.pop(sheetContext,true);}catch(error){setSheetState(()=>submitting=false);if(sheetContext.mounted)ToastService.showError(sheetContext,error.toString(),title:'Không thể gửi kháng cáo');}},child:submitting?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Text('Gửi kháng cáo')))]))));
    controller.dispose();if(submitted==true){await _load();if(mounted)ToastService.showSuccess(context,'Kháng cáo đã được gửi. Chúng tôi sẽ thông báo khi có kết quả.',title:'Đã gửi kháng cáo');}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(leading:CupertinoButton(padding:const EdgeInsets.only(left:8),onPressed:()=>Navigator.of(context).maybePop(),child:const Icon(CupertinoIcons.chevron_back,size:22)),title: const Text('Chi tiết thông báo'), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_circle, size: 44),
                        const SizedBox(height: 12),
                        Text(_error.toString(), textAlign: TextAlign.center),
                        TextButton(onPressed: _load, child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : _detail == null
                  ? const Center(child: Text('Thông báo không tồn tại hoặc bạn không có quyền xem.'))
                  : _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme){final detail=_detail!;final action=Map<String,dynamic>.from(detail['action'] as Map? ?? {});final report=Map<String,dynamic>.from(detail['report'] as Map? ?? {});final content=Map<String,dynamic>.from(detail['reported_content'] as Map? ?? {});final appeal=detail['appeal'] is Map?Map<String,dynamic>.from(detail['appeal'] as Map):null;final canAppeal=detail['can_appeal']==true;final actionType=action['action_type']?.toString();return RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(18),children:[Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:theme.colorScheme.primaryContainer,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(actionType=='restore'?CupertinoIcons.checkmark_shield_fill:CupertinoIcons.exclamationmark_shield_fill,color:theme.colorScheme.primary,size:34),const SizedBox(height:14),Text(_decisionLabel(actionType),style:theme.textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:7),Text(detail['content']?.toString()??'Quyết định kiểm duyệt đã được cập nhật.',style:theme.textTheme.bodyMedium)])),const SizedBox(height:16),_InfoCard(title:'Nội dung liên quan',icon:CupertinoIcons.doc_text,children:[_InfoRow(label:'Loại nội dung',value:action['content_type']?.toString()??'—'),_InfoRow(label:'Nội dung',value:content['text']?.toString()??'Nội dung không còn khả dụng'),_InfoRow(label:'Lý do báo cáo',value:report['reason']?.toString()??'—')]),const SizedBox(height:12),_InfoCard(title:'Kết quả xem xét',icon:CupertinoIcons.shield,children:[_InfoRow(label:'Quyết định',value:_decisionLabel(actionType)),_InfoRow(label:'Lý do xử lý',value:action['reason']?.toString()??'Theo Tiêu chuẩn cộng đồng'),_InfoRow(label:'Thời gian',value:_formatDate(action['created_at']))]),if(appeal!=null)...[const SizedBox(height:12),_InfoCard(title:'Kháng cáo của bạn',icon:CupertinoIcons.arrow_counterclockwise,children:[_InfoRow(label:'Trạng thái',value:_appealStatus(appeal['status']?.toString())),_InfoRow(label:'Nội dung',value:appeal['appeal_reason']?.toString()??'—'),if(appeal['reviewer_note']!=null)_InfoRow(label:'Phản hồi',value:appeal['reviewer_note'].toString())])],if(canAppeal)...[const SizedBox(height:22),FilledButton.icon(onPressed:_openAppealSheet,icon:const Icon(CupertinoIcons.arrow_counterclockwise),label:const Text('Kháng cáo quyết định'),style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52)))],const SizedBox(height:36)]));}
  String _appealStatus(String? status)=>switch(status){'pending'=>'Đã gửi','in_review'=>'Đang xem xét','resolved_unchanged'=>'Quyết định không thay đổi','resolved_published'=>'Được phép hiển thị','resolved_limited'=>'Được phép hiển thị nhưng bị hạn chế','approved'=>'Đã chấp nhận','rejected'=>'Đã từ chối',_=>'Không xác định'};
  String _formatDate(dynamic value){final date=DateTime.tryParse(value?.toString()??'')?.toLocal();if(date==null)return '—';return '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')} · ${date.day}/${date.month}/${date.year}';}
}

class _InfoCard extends StatelessWidget{final String title;final IconData icon;final List<Widget> children;const _InfoCard({required this.title,required this.icon,required this.children});@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:Theme.of(context).cardColor,borderRadius:BorderRadius.circular(18),border:Border.all(color:Theme.of(context).dividerColor.withValues(alpha:.5))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,size:19,color:Theme.of(context).colorScheme.primary),const SizedBox(width:9),Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16))]),const Divider(height:26),...children]));}
class _InfoRow extends StatelessWidget{final String label,value;const _InfoRow({required this.label,required this.value});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:TextStyle(fontSize:12,color:Theme.of(context).hintColor)),const SizedBox(height:3),Text(value,style:const TextStyle(fontSize:15,height:1.4))]));}
