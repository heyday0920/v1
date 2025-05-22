import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TimelineScreen extends StatefulWidget {
  @override
  _TimelineScreenState createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      print('レビューの読み込みを開始');
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5000/reviews'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      print('APIレスポンス: ${response.statusCode}');
      print('レスポンスボディ: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        print('取得したレビュー数: ${_reviews.length}');
      } else {
        throw Exception('Failed to load reviews: ${response.statusCode}');
      }
    } catch (e) {
      print('レビュー読み込みエラー: $e');
      setState(() {
        _error = 'レビューの読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('タイムライン'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _reviews.isEmpty
                  ? Center(child: Text('まだレビューがありません'))
                  : RefreshIndicator(
                      onRefresh: _loadReviews,
                      child: ListView.builder(
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) {
                          final review = _reviews[index];
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
                                        child: Text(
                                          (review['user_id'] ?? 'U')[0].toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        backgroundColor: Colors.blue,
                                        radius: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            review['user_id'] ?? '匿名ユーザー',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            review['user_location'] ?? '不明な場所',
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
                                    review['restaurant_id'] ?? 'レストラン名',
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
                                        review['rating']?.toString() ?? '0',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(review['review_text'] ?? ''),
                                  SizedBox(height: 12),
                                  if (index % 3 == 0) // 3の倍数の投稿にのみ画像を表示
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        'https://picsum.photos/400/300?random=$index',
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 200,
                                            width: double.infinity,
                                            color: Colors.grey[300],
                                            child: Icon(Icons.image_not_supported, size: 50),
                                          );
                                        },
                                      ),
                                    ),
                                  SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.favorite_border, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Text('${index * 10 + 5}'),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.chat_bubble_outline, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Text('${index * 2 + 1}'),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.share, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Text('${index + 1}'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // レビュー投稿画面への遷移
        },
        child: Icon(Icons.edit),
        backgroundColor: Colors.blue,
      ),
    );
  }
} 