import 'package:flutter/material.dart';

class SingLearnApp extends StatelessWidget {
  const SingLearnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SingLearn',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('SingLearn')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Học tiếng Anh qua bài hát',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text('Nhóm 10 · 65KTPM', textAlign: TextAlign.center),
                  SizedBox(height: 16),
                  Text(
                    'Khung dự án ban đầu. Các tính năng theo đề cương TH4 '
                    'chưa được triển khai.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
