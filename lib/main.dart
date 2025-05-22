import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:page_transition/page_transition.dart'; // page_transitionパッケージをインポート
import 'screens/reservation_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  runApp(RestaurantSwipeApp());
}

class RestaurantSwipeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
      theme: ThemeData(
        fontFamily: 'NotoSansJP',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login() {
    Navigator.of(context).pushReplacement(
      PageTransition(
        type: PageTransitionType.fade,
        child: RestaurantSwipeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ログイン")),
      body: Stack(
        children: <Widget>[
          Opacity(
            opacity: 0.7,
            child: Image.network(
              'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1470&q=80',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                print("背景画像読み込みエラー: $error");
                return Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: Icon(Icons.restaurant, size: 100, color: Colors.grey[600]),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "メールアドレス",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: "パスワード",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(
                    "ログイン",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RestaurantSwipeScreen extends StatefulWidget {
  @override
  _RestaurantSwipeScreenState createState() => _RestaurantSwipeScreenState();
}

class _RestaurantSwipeScreenState extends State<RestaurantSwipeScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> restaurants = [];
  List<Map<String, dynamic>> likedRestaurants = [];
  List<Map<String, dynamic>> nopedRestaurants = [];
  bool isLoading = true;
  double? currentLat;
  double? currentLon;
  int swipeCount = 0;
  int currentIndex = 0;

  final CardSwiperController _controller = CardSwiperController();
  final ScrollController _reviewsScrollController = ScrollController();

  // Animation Controllers
  late AnimationController _likeButtonAnimationController;
  late Animation<double> _likeButtonAnimation;
  late AnimationController _nopeButtonAnimationController;
  late Animation<double> _nopeButtonAnimation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

    // LIKE button animation setup
    _likeButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _likeButtonAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
          parent: _likeButtonAnimationController, curve: Curves.easeOut),
    );

    // NOPE button animation setup
    _nopeButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _nopeButtonAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
          parent: _nopeButtonAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _reviewsScrollController.dispose();
    _likeButtonAnimationController.dispose(); // MODIFIED: Dispose controller
    _nopeButtonAnimationController.dispose(); // MODIFIED: Dispose controller
    super.dispose();
  }

  // Helper function to trigger bounce
  void _triggerBounceAnimation(AnimationController controller) {
    controller.forward().then((_) {
      controller.reverse();
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => isLoading = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => isLoading = false);
          return;
        }
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      currentLat = position.latitude;
      currentLon = position.longitude;
      await fetchNearbyRestaurants(currentLat!, currentLon!);
    } catch (e) {
      print("位置情報取得エラー: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchNearbyRestaurants(double latitude, double longitude) async {
    try {
      print("位置情報: 緯度=$latitude, 経度=$longitude");
      final baseUrl = "http://10.0.2.2:5000";
      final url = Uri.parse("$baseUrl/nearby_restaurants");
      print("APIリクエスト送信: $url");
      
      final client = http.Client();
      try {
        final response = await client.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Connection': 'keep-alive',
          },
          body: json.encode({
            "latitude": latitude,
            "longitude": longitude,
            "radius": 10000,
            "type": "restaurant"
          }),
        ).timeout(Duration(seconds: 30));

        print("APIレスポンス: ${response.statusCode}");
        print("APIレスポンス本文: ${response.body}");
        if (response.statusCode == 200) {
          List<dynamic> data = json.decode(response.body);
          print("デコードされたデータ: $data");  // デバッグ用
          setState(() {
            restaurants = List<Map<String, dynamic>>.from(data);
            print("変換後のレストランデータ: $restaurants");  // デバッグ用
            isLoading = false;
          });
          print("取得したレストラン数: ${restaurants.length}");
        } else {
          print("飲食店データの取得失敗: ${response.statusCode}, Body: ${response.body}");
          setState(() {
            isLoading = false;
            restaurants = [];
          });
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print("飲食店データの取得エラー: $e");
      setState(() {
        isLoading = false;
        restaurants = [];
      });
    }
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final uri = Uri.parse("tel:$phoneNumber");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('電話アプリを開けませんでした。')));
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecommended(
    List<String> likedGenres,
  ) async {
    try {
      final baseUrl = "http://10.0.2.2:5000";
      final url = Uri.parse("$baseUrl/recommend_restaurants");
      print("リコメンドAPIリクエスト送信: $url");
      
      final client = http.Client();
      try {
        final response = await client.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Connection': 'keep-alive',
          },
          body: json.encode({
            "latitude": currentLat,
            "longitude": currentLon,
            "liked_restaurants": likedRestaurants,
            "noped_restaurants": nopedRestaurants,
          }),
        ).timeout(Duration(seconds: 30));

        print("リコメンドAPIレスポンス: ${response.statusCode}");
        if (response.statusCode == 200) {
          List<dynamic> data = json.decode(response.body);
          print("取得したリコメンド数: ${data.length}");
          return List<Map<String, dynamic>>.from(data);
        } else {
          print("リコメンド取得失敗: ${response.statusCode}, Body: ${response.body}");
          return [];
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print("リコメンド取得エラー: $e");
      return [];
    }
  }

  void _tryGoToRecommend(BuildContext context) {
    if (swipeCount >= 5) {
      List<String> likedGenres = likedRestaurants
          .map((e) => (e["genre"] as String? ?? "").split(","))
          .expand((e) => e)
          .where((genre) => genre.trim().isNotEmpty)
          .toList();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecommendedScreen(
            genres: likedGenres,
            latitude: currentLat!,
            longitude: currentLon!,
            fetchRecommended: fetchRecommended,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (swipeCount >= 5) {
      Future.microtask(() => _tryGoToRecommend(context));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("飲食店スワイプ"),
        backgroundColor: Colors.deepOrange,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : restaurants.isEmpty
              ? Center(child: Text("お店が見つかりませんでした"))
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: CardSwiper(
                          controller: _controller,
                          cardsCount: restaurants.length,
                          numberOfCardsDisplayed: 1,
                          cardBuilder: (context, index, realIndex, cardsCount) {
                            final restaurant = restaurants[index];
                            return _buildRestaurantCard(context, restaurant,
                              userLat: currentLat,
                              userLon: currentLon,
                              onCallPressed: () {
                                if (restaurant['phone'] != null && restaurant['phone'].isNotEmpty) {
                                  _launchPhone(restaurant['phone']);
                                }
                              },
                              onFavoritePressed: () async {
                                try {
                                  print('お気に入り追加リクエスト: ${restaurant['place_id']}');
                                  print('レストランデータ: $restaurant');  // デバッグ用
                                  if (restaurant['place_id'] == null) {
                                    print('place_idが見つかりません');  // デバッグ用
                                    throw Exception('place_id is required');
                                  }
                                  final response = await http.post(
                                    Uri.parse('http://10.0.2.2:5000/favorites'),
                                    headers: {'Content-Type': 'application/json'},
                                    body: json.encode({
                                      'user_id': 'anonymous_user',
                                      'restaurant': {
                                        'place_id': restaurant['place_id'],
                                        'name': restaurant['name'] ?? '',
                                        'address': restaurant['address'] ?? '',
                                        'rating': restaurant['rating'] ?? 0.0,
                                        'user_ratings_total': restaurant['user_ratings_total'] ?? 0,
                                        'photo_reference': restaurant['photo_reference'],
                                        'latitude': restaurant['latitude'] ?? 0.0,
                                        'longitude': restaurant['longitude'] ?? 0.0
                                      }
                                    }),
                                  );
                                  print('お気に入り追加レスポンス: ${response.statusCode}');
                                  print('お気に入り追加レスポンス本文: ${response.body}');
                                  if (response.statusCode == 200) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('お気に入りに追加しました')),
                                    );
                                  } else {
                                    throw Exception('Failed to add favorite');
                                  }
                                } catch (e) {
                                  print('お気に入り登録エラー: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('お気に入りの登録に失敗しました')),
                                  );
                                }
                              }
                            );
                          },
                          onSwipe: (previousIndex, currentIndex, direction) {
                            final restaurant = restaurants[previousIndex];
                            if (direction == CardSwiperDirection.right) {
                              likedRestaurants.add(restaurant);
                              _triggerBounceAnimation(_likeButtonAnimationController);
                              print("LIKEしたお店: ${restaurant["name"]}");
                            } else if (direction == CardSwiperDirection.left) {
                              nopedRestaurants.add(restaurant);
                              _triggerBounceAnimation(_nopeButtonAnimationController);
                              print("NOPEしたお店: ${restaurant["name"]}");
                            }
                            setState(() {
                              if (currentIndex != null) {
                                this.currentIndex = currentIndex;
                              }
                              swipeCount++;
                            });
                            return true;
                          },
                          allowedSwipeDirection: AllowedSwipeDirection.symmetric(
                            horizontal: true,
                            vertical: false,
                          ),
                          isDisabled: false,
                          backCardOffset: Offset(40, 40),
                          padding: EdgeInsets.all(16.0),
                        ),
                      ),
                      Container(
                        height: 60,
                        child: _buildActionButtons(context),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: buildCommonBottomNavigationBar(context, currentIndex: 0),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ScaleTransition(
          scale: _nopeButtonAnimation,
          child: ElevatedButton(
            onPressed: () {
              _triggerBounceAnimation(_nopeButtonAnimationController);
              final restaurant = restaurants[currentIndex];
              nopedRestaurants.add(restaurant);
              setState(() {
                swipeCount++;
              });
              _controller.swipeLeft();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade400,
              minimumSize: Size(90, 45),
            ),
            child: Text("NOPE", style: TextStyle(fontSize: 16)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReservationScreen(
                  restaurant: restaurants[currentIndex],
                ),
              ),
            );
          },
          icon: Icon(Icons.calendar_today),
          label: Text('予約する'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            minimumSize: Size(90, 45),
          ),
        ),
        ScaleTransition(
          scale: _likeButtonAnimation,
          child: ElevatedButton(
            onPressed: () {
              _triggerBounceAnimation(_likeButtonAnimationController);
              final restaurant = restaurants[currentIndex];
              likedRestaurants.add(restaurant);
              setState(() {
                swipeCount++;
              });
              _controller.swipeRight();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellowAccent.shade700,
              minimumSize: Size(90, 45),
            ),
            child: Text("LIKE", style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

// おすすめ画面
class RecommendedScreen extends StatelessWidget {
  final List<String> genres;
  final double latitude;
  final double longitude;
  final Future<List<Map<String, dynamic>>> Function(List<String>)
      fetchRecommended;

  RecommendedScreen({
    required this.genres,
    required this.latitude,
    required this.longitude,
    required this.fetchRecommended,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("あなたへのおすすめ")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchRecommended(genres),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("おすすめの取得中にエラーが発生しました: ${snapshot.error}"));
          }
          final recommended = snapshot.data!;
          return recommended.isEmpty
              ? Center(child: Text("条件に合うおすすめ店舗が見つかりませんでした"))
              : ListView.builder(
                  itemCount: recommended.length,
                  itemBuilder: (context, index) {
                    final shop = recommended[index];
                    return Card(
                      margin: EdgeInsets.all(12),
                      child: ListTile(
                        leading: Image.network(
                          shop["image_url"] ?? "",
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.restaurant,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        title: Text(shop["name"] ?? ""),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("評価: ${shop["rating"] ?? "-"}"),
                            Text(shop["address"] ?? ""),
                            if ((shop["phone"] ?? "").isNotEmpty)
                              Text("電話: ${shop["phone"]}"),
                          ],
                        ),
                      ),
                    );
                  },
                );
        },
      ),
      bottomNavigationBar: buildCommonBottomNavigationBar(context, currentIndex: 0),
    );
  }
}

// レストランカードウィジェット
Widget _buildRestaurantCard(BuildContext context, Map<String, dynamic> restaurant, {double? userLat, double? userLon, VoidCallback? onCallPressed, VoidCallback? onFavoritePressed}) {
  print('レストランカードデータ: $restaurant');  // デバッグ用
  String? photoUrl;
  if (restaurant['photo_references'] != null && restaurant['photo_references'].isNotEmpty) {
    final photoRef = Uri.encodeComponent(restaurant['photo_references'][0]);
    photoUrl = 'http://10.0.2.2:5000/place_photos?photo_references[]=$photoRef';
  }

  // 距離計算
  String distanceText = '';
  if (userLat != null && userLon != null && restaurant['latitude'] != null && restaurant['longitude'] != null) {
    double distanceInMeters = Geolocator.distanceBetween(
      userLat,
      userLon,
      restaurant['latitude'],
      restaurant['longitude'],
    );
    if (distanceInMeters < 1000) {
      distanceText = '${distanceInMeters.round()}m';
    } else {
      distanceText = '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  return Center(
    child: Material(
      elevation: 20,
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
      child: Container(
        width: 350, // カードの幅を固定
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像とオーバーレイ情報
            SizedBox(
              height: 250, // 高さを増やしてオーバーフローを防ぐ
              child: Stack(
                fit: StackFit.expand, // Stackの子要素を親のサイズに合わせる
                children: [
                  // 画像
                  if (photoUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        photoUrl,
                        height: 250, // 画像の高さも調整
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 250,
                            color: Colors.grey[300],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print("画像読み込みエラー: $error");
                          return Container(
                            height: 250,
                            color: Colors.grey[300],
                            child: Icon(Icons.restaurant, size: 80, color: Colors.grey),
                          );
                        },
                      ),
                    ),

                  // 画像の上に重ねる情報（お気に入り数など）
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.favorite, color: Colors.red, size: 20),
                          SizedBox(width: 4),
                          Text(
                            '1919', // 仮のお気に入り数
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 画像の上に重ねる情報（店舗名と距離）
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant['name'] ?? '店舗名不明',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(blurRadius: 2, color: Colors.black)]
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                             Icon(Icons.location_on, color: Colors.white, size: 16),
                             SizedBox(width: 4),
                             Text(
                              distanceText, // 距離を表示
                               style: TextStyle(
                                 fontSize: 14,
                                 color: Colors.white,
                                 shadows: [Shadow(blurRadius: 2, color: Colors.black)]
                               )
                             ),
                             SizedBox(width: 8),
                             Icon(Icons.star, color: Colors.orange, size: 16),
                             SizedBox(width: 4),
                             Text(
                               '${restaurant['rating'] ?? 0.0}', // レーティングを表示
                               style: TextStyle(
                                 fontSize: 14,
                                 color: Colors.white,
                                 shadows: [Shadow(blurRadius: 2, color: Colors.black)]
                               ),
                             ),
                          ],
                        )
                      ],
                    ),
                  ),

                  // お気に入りボタン（画像オーバーレイ内）
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: onFavoritePressed,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite_border,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 画像の下の店舗詳細とボタン
            Padding(
              padding: const EdgeInsets.all(16.0), // パディングを追加
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 追加の店舗情報（必要に応じて）
                  // 例：営業時間、電話番号など
                ],
              ),
            ),

            // 電話番号ボタン (イメージに合わせて追加)
            if (restaurant['phone'] != null && restaurant['phone'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: ElevatedButton.icon(
                  onPressed: onCallPressed,
                  icon: Icon(Icons.phone),
                  label: Text('電話をかける'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: Size(double.infinity, 40),
                  ),
                ),
              ),

            // 予約ボタン (既存を維持)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReservationScreen(
                        restaurant: restaurant,
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.calendar_today),
                label: Text('予約する'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: Size(double.infinity, 40),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// 共通のボトムナビゲーションバー
Widget buildCommonBottomNavigationBar(BuildContext context, {int currentIndex = 0}) {
  return BottomNavigationBar(
    currentIndex: currentIndex,
    items: [
      BottomNavigationBarItem(
        icon: Icon(Icons.thumb_up),
        label: 'リコメンド',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.access_time),
        label: 'タイムライン',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'プロフィール',
      ),
    ],
    onTap: (index) {
      switch (index) {
        case 0:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => RestaurantSwipeScreen()),
          );
          break;
        case 1:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TimelineScreen()),
          );
          break;
        case 2:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ProfileScreen()),
          );
          break;
      }
    },
  );
}

// タイムライン画面
class TimelineScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('タイムライン'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        child: Icon(Icons.person, color: Colors.grey[600]),
                        radius: 20,
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ユーザー${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${DateTime.now().subtract(Duration(hours: index)).toString().substring(0, 16)}',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'お店の名前${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 20),
                      SizedBox(width: 4),
                      Text(
                        '${4.0 + (index % 2) * 0.5}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'このお店は本当に素晴らしかったです！料理の質が高く、サービスも丁寧でした。特に${index + 1}番目の料理が印象的でした。また行きたいと思います。',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  if (index % 3 == 0)
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(Icons.restaurant, size: 50, color: Colors.grey[600]),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: buildCommonBottomNavigationBar(context, currentIndex: 1),
    );
  }
}

Future<Map<String, dynamic>> fetchProfile(String userId) async {
  try {
    final baseUrl = "http://10.0.2.2:5000";
    final url = Uri.parse("$baseUrl/profile/$userId");
    print("プロフィールAPIリクエスト送信: $url");
    
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print("プロフィール取得エラー: ${response.statusCode}");
      return {};
    }
  } catch (e) {
    print("プロフィール読み込みエラー: $e");
    return {};
  }
}

Future<bool> saveProfile(Map<String, dynamic> profileData) async {
  try {
    final baseUrl = "http://10.0.2.2:5000";
    final url = Uri.parse("$baseUrl/profile");
    print("プロフィール保存APIリクエスト送信: $url");
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(profileData),
    );
    return response.statusCode == 200;
  } catch (e) {
    print("プロフィール保存エラー: $e");
    return false;
  }
}
