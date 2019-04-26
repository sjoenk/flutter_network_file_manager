import 'package:flutter/material.dart';
import 'package:flutter_network_file_manager/flutter_network_file_manager.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FileInfo fileInfo;

  _downloadFile() {
    String url = 'https://cdn2.online-convert.com/example-file/raster%20image/png/example_small.png';
    String name = "example_small_2";
    DateTime timestamp = DateTime.parse("2019-04-19 18:50:00");

    DefaultFileManager()
        .getFile(
      name: name,
      url: url,
      timestamp: timestamp,
    )
        .listen((FileInfo f) {
      setState(() {
        fileInfo = f;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    String path = "N/A";
    String name = "N/A";
    String from = "N/A";

    if (fileInfo != null) {
      path = fileInfo.file?.path ?? path;
      name = fileInfo.name ?? name;
      from = fileInfo.source?.toString() ?? from;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Local filePath:',
            ),
            Text(
              path,
            ),
            Text(
              'Name: $name',
            ),
            Text(
              'From: $from',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 32.0),
              child: RaisedButton(
                child: Text('DELETE ALL'),
                onPressed: () {
                  DefaultFileManager().deleteAll();
                },
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _downloadFile,
        tooltip: 'Download',
        child: Icon(Icons.add),
      ),
    );
  }
}
