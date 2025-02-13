import 'package:flutter/material.dart';

import '../helper/global.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override 
  void initState(){
    super.initState();
    Future.delayed(Duration(seconds: 2),() {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
    );
  }

  @override
  Widget build(BuildContext context) {

    mq = MediaQuery.sizeOf(context); 
    return Scaffold(
      body: Center(
        child: Card(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            child: Image.asset("assets/Noria.png", width: mq.width * .45),
          ), 
          ),
      ),
      
    );
  }
}