import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

// Emulator: http://10.0.2.2:8000. Physical phone: use your computer/server LAN or HTTPS URL.
const apiBase = String.fromEnvironment('SHUTTLEAI_API', defaultValue: 'http://10.0.2.2:8000');
const matchId = 'demo-match';
void main() => runApp(const ShuttleAIApp());

class ShuttleAIApp extends StatelessWidget {
  const ShuttleAIApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'ShuttleAI', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0C7657), brightness: Brightness.dark), useMaterial3: true),
    home: const Dashboard());
}

class Dashboard extends StatefulWidget { const Dashboard({super.key}); @override State<Dashboard> createState()=>_DashboardState(); }
class _DashboardState extends State<Dashboard> {
  CameraController? _camera; List<CameraDescription> _cameras=[]; String _cameraMessage='กล้องยังไม่เริ่ม';
  String _apiMessage='ยังไม่ได้ทดสอบการเชื่อมต่อ'; bool _apiOk=false; bool _busy=false;
  Map<String,dynamic> _score={'side_a':'ฝั่ง A','side_b':'ฝั่ง B','points_a':0,'points_b':0,'status':'setup','ai_status':'not_integrated'};
  WebSocketChannel? _channel; StreamSubscription? _subscription;
  @override void initState(){super.initState(); _startCamera(); _connectApi();}
  Future<void> _startCamera() async {
    try { _cameras=await availableCameras(); if(_cameras.isEmpty){setState(()=>_cameraMessage='ไม่พบกล้อง');return;}
      final selected=_cameras.firstWhere((c)=>c.lensDirection==CameraLensDirection.back,orElse:()=>_cameras.first);
      final controller=CameraController(selected,ResolutionPreset.high,enableAudio:false);
      await controller.initialize(); if(!mounted){await controller.dispose();return;}
      setState(()=>{_camera=controller,_cameraMessage='กล้องพร้อม • ${selected.name}'});
    } catch(e){if(mounted)setState(()=>_cameraMessage='เปิดกล้องไม่สำเร็จ: $e');}
  }
  Future<void> _connectApi() async {
    try { final r=await http.get(Uri.parse('$apiBase/health')).timeout(const Duration(seconds:5));
      if(r.statusCode!=200) throw Exception('HTTP ${r.statusCode}');
      final data=jsonDecode(r.body) as Map<String,dynamic>;
      if(mounted)setState(()=>{_apiOk=true,_apiMessage='Cloud API เชื่อมต่อแล้ว • AI: ${data['vision_model']}'});
      _channel=WebSocketChannel.connect(Uri.parse(apiBase.replaceFirst('https://','wss://').replaceFirst('http://','ws://')+'/ws/scores/$matchId'));
      _subscription=_channel!.stream.listen((event){try{final m=jsonDecode(event as String) as Map<String,dynamic>;if(mounted)setState(()=>_score=m);}catch(_){}});
      await http.post(Uri.parse('$apiBase/matches'),headers:{'Content-Type':'application/json'},body:jsonEncode({'match_id':matchId,'side_a':'ฝั่ง A','side_b':'ฝั่ง B'}));
    } catch(e){if(mounted)setState(()=>{_apiOk=false,_apiMessage='ยังเชื่อม Cloud API ไม่ได้: $e'});}
  }
  Future<void> _award(String side) async {
    if(!_apiOk||_busy)return; setState(()=>_busy=true);
    try {final r=await http.post(Uri.parse('$apiBase/matches/$matchId/events'),headers:{'Content-Type':'application/json'},body:jsonEncode({'match_id':matchId,'event_key':'manual-${DateTime.now().microsecondsSinceEpoch}','source':'manual','point_to':side,'reason':'ทดสอบโดยผู้ใช้'})).timeout(const Duration(seconds:5));
      if(r.statusCode>=300)throw Exception('HTTP ${r.statusCode}');
      final data=jsonDecode(r.body); if(data['score']!=null&&mounted)setState(()=>_score=Map<String,dynamic>.from(data['score']));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('ส่งคะแนนไม่สำเร็จ: $e')));}finally{if(mounted)setState(()=>_busy=false);}
  }
  @override void dispose(){_subscription?.cancel();_channel?.sink.close();_camera?.dispose();super.dispose();}
  @override Widget build(BuildContext context){final cam=_camera;return Scaffold(appBar:AppBar(title:const Text('ShuttleAI'),subtitle:const Text('BADMINTON AI • PROTOTYPE'),actions:[IconButton(onPressed:_connectApi,icon:const Icon(Icons.refresh),tooltip:'เชื่อมต่อใหม่')]),body:ListView(padding:const EdgeInsets.all(16),children:[
    Container(height:220,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:Colors.black,borderRadius:BorderRadius.circular(18)),child:cam!=null&&cam.value.isInitialized?CameraPreview(cam):Center(child:Text(_cameraMessage,textAlign:TextAlign.center))),
    const SizedBox(height:8),Text(_cameraMessage,style:Theme.of(context).textTheme.bodySmall),const SizedBox(height:16),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(_apiOk?Icons.cloud_done:Icons.cloud_off,color:_apiOk?Colors.green:Colors.orange),const SizedBox(width:8),Expanded(child:Text(_apiMessage))]),const SizedBox(height:8),const Text('สถานะ AI: ยังไม่มีโมเดลตัดสินแต้มเชื่อมต่อ',style:TextStyle(color:Colors.amber)),const Text('คะแนนอัตโนมัติถูกปิดไว้จนกว่าจะทดสอบโมเดลกับวิดีโอจริง',style:TextStyle(fontSize:12))]))),
    const SizedBox(height:12),Row(children:[Expanded(child:_scoreCard('ฝั่ง A',_score['points_a']??0)),const SizedBox(width:12),Expanded(child:_scoreCard('ฝั่ง B',_score['points_b']??0))]),const SizedBox(height:12),
    const Text('ปุ่มด้านล่างใช้ทดสอบการเชื่อมต่อและการซิงก์คะแนนเท่านั้น'),const SizedBox(height:8),Row(children:[Expanded(child:FilledButton(onPressed:_busy?null:()=>_award('A'),child:const Text('+1 ฝั่ง A (ทดสอบ)'))),const SizedBox(width:8),Expanded(child:FilledButton(onPressed:_busy?null:()=>_award('B'),child:const Text('+1 ฝั่ง B (ทดสอบ)')))]),
    const SizedBox(height:18),OutlinedButton.icon(onPressed:()=>showAboutDialog(context:context,applicationName:'ShuttleAI',applicationVersion:'0.1.0 prototype',children:[const Text('ต้นแบบนี้ยังไม่วิเคราะห์ลูกแบดจากภาพและไม่ตัดสินผู้ชนะอัตโนมัติ')]),icon:const Icon(Icons.info_outline),label:const Text('ข้อมูลต้นแบบและข้อจำกัด')),
  ]));}
  Widget _scoreCard(String label,dynamic score)=>Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFF153C32),borderRadius:BorderRadius.circular(18)),child:Column(children:[Text(label),const SizedBox(height:8),Text('$score',style:const TextStyle(fontSize:42,fontWeight:FontWeight.bold))]));
}
