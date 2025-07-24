import 'dart:io';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await AndroidAlarmManager.initialize(); // Ajouté
    await MobileAds.instance.initialize();
    await NotificationService().init();

    // Planifier toutes les 6 heures
    AndroidAlarmManager.periodic(
      const Duration(seconds: 16),
      0, // ID de tâche unique
      NotificationService.sendScheduledQuoteNotification,
      exact: true,
      wakeup: true,
    );
  }

  runApp(InspireMoiApp());
}

class InspireMoiApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inspire-moi',
      theme: ThemeData.dark(),
      home: CitationScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CitationScreen extends StatefulWidget {
  @override
  _CitationScreenState createState() => _CitationScreenState();
}

class _CitationScreenState extends State<CitationScreen> {
  String citation = "";
  String auteur = "";
  bool isLoading = false;

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    fetchCitation();
    if (!kIsWeb) _loadAd();
  }

  void _loadAd() {
    final adUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/9214589741'
        : 'ca-app-pub-3940256099942544/2435281174';
    _bannerAd = BannerAd(
      adUnitId:'ca-app-pub-3940256099942544/9214589741', // Replace with real ID
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('$ad loaded.');
          setState(() {
            _isBannerAdReady = true;
            print("000000000000");
          });
        },
        onAdFailedToLoad: (ad, error) {

          debugPrint('BannerAd failed to load: $error');
          setState(() {
            _isBannerAdReady = false;
            print("111111111111111111111111 ${error.message}");
          });
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> fetchCitation() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse('https://zenquotes.io/api/random'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          citation = data[0]['q'] ?? "Citation indisponible";
          auteur = data[0]['a'] ?? "Inconnu";
        });
      } else {
        setState(() {
          citation = "Erreur de chargement";
          auteur = "";
        });
      }
    } catch (e) {
      setState(() {
        citation = "Erreur réseau : ${e.toString()}";
        auteur = "";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inspire-moi'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Center(
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: citation.isEmpty
                    ? CircularProgressIndicator()
                    : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '"$citation"',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '- $auteur',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: GestureDetector(
                    onTap: isLoading ? null : fetchCitation,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: isLoading ? Colors.grey.withOpacity(0.2) : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),

                      ),
                      child: isLoading
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        'Nouvelle citation',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            if (!kIsWeb && _isBannerAdReady)
              Container(
                height: _bannerAd!.size.height.toDouble(),
                width: _bannerAd!.size.width.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }
}


class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();
  static Future<void> sendScheduledQuoteNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await plugin.initialize(settings);

    final response = await http.get(Uri.parse('https://zenquotes.io/api/random'));
    String message = 'Découvre une nouvelle citation !';

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final quote = data[0]['q'] ?? "Citation indisponible";
      final author = data[0]['a'] ?? "Inconnu";
      message = '"$quote" - $author';
    }

    await plugin.show(
      0,
      'Citation inspirante',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'inspire_channel',
          'Inspire-moi Channel',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }
  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notificationsPlugin.initialize(settings);

    // Android 13+ permissions
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> scheduleNotificationEvery6Hours() async {
    final response = await http.get(Uri.parse('https://zenquotes.io/api/random'));
    String message = 'Découvre une nouvelle citation !';

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final quote = data[0]['q'] ?? "Citation indisponible";
      final author = data[0]['a'] ?? "Inconnu";
      message = '"$quote" - $author';
    }

    await _notificationsPlugin.zonedSchedule(
      0,
      'Citation inspirante',
      message,
      _nextInstanceAfter(const Duration(minutes: 1)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'inspire_channel',
          'Inspire-moi Channel',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> showTestNotification() async {
    await _notificationsPlugin.show(
      0,
      'Test',
      'Ceci est une notification de test',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'inspire_channel',
          'Inspire-moi Channel',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  tz.TZDateTime _nextInstanceAfter(Duration duration) {
    final now = tz.TZDateTime.now(tz.local);
    return now.add(duration);
  }
}
