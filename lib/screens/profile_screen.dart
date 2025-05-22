import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../main.dart' show buildCommonBottomNavigationBar, fetchProfile, saveProfile;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _residenceController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String? _selectedGender;
  List<String> _preferences = [];
  bool _isLoading = true;
  bool _isLoadingFavorites = true;
  List<Map<String, dynamic>> _favoriteRestaurants = [];
  String _profileIcon = '👤';
  String? _profileImageUrl;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadFavorites();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _residenceController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await fetchProfile('anonymous_user');
      setState(() {
        _bioController.text = profile['bio'] ?? '';
        _residenceController.text = profile['residence'] ?? '';
        _ageController.text = profile['age']?.toString() ?? '';
        _selectedGender = profile['gender'] ?? '未選択';
        _preferences = List<String>.from(profile['preferences'] ?? []);
        _profileIcon = profile['icon'] ?? '��';
        _profileImageUrl = profile['profile_image_url'];
        _followersCount = profile['followers_count'] ?? 0;
        _followingCount = profile['following_count'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      print("プロフィール読み込みエラー: $e");
      setState(() {
        _isLoading = false;
        _selectedGender = '未選択';
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (image != null) {
        // 画像をアップロード
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        final response = await http.post(
          Uri.parse('http://10.0.2.2:5000/upload_profile_image'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': 'anonymous_user',
            'image_data': base64Image,
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _profileImageUrl = data['image_url'];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('プロフィール画像を更新しました')),
          );
        } else {
          throw Exception('Failed to upload image');
        }
      }
    } catch (e) {
      print("画像アップロードエラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像のアップロードに失敗しました')),
      );
    }
  }

  Future<void> _saveProfile() async {
    try {
      final profileData = {
        'user_id': 'anonymous_user',
        'residence': _residenceController.text,
        'age': int.tryParse(_ageController.text) ?? 0,
        'gender': _selectedGender,
        'bio': _bioController.text,
        'preferences': _preferences,
        'icon': _profileIcon,
        'profile_image_url': _profileImageUrl,
        'followers_count': _followersCount,
        'following_count': _followingCount,
      };
      final success = await saveProfile(profileData);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('プロフィールを保存しました')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('プロフィールの保存に失敗しました')),
        );
      }
    } catch (e) {
      print("プロフィール保存エラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('プロフィールの保存中にエラーが発生しました')),
      );
    }
  }

  Future<void> _loadFavorites() async {
    try {
      setState(() {
        _isLoadingFavorites = true;
      });
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/favorites/anonymous_user'),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          _favoriteRestaurants = List<Map<String, dynamic>>.from(data);
          _isLoadingFavorites = false;
        });
      } else {
        print("お気に入り取得失敗: ${response.statusCode}, Body: ${response.body}");
        setState(() {
          _isLoadingFavorites = false;
        });
      }
    } catch (e) {
      print("お気に入り読み込みエラー: $e");
      setState(() {
        _isLoadingFavorites = false;
      });
    }
  }

  Future<void> _removeFavorite(String placeId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://10.0.2.2:5000/favorites/anonymous_user/$placeId'),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('お気に入りから削除しました')),
        );
        _loadFavorites();
      } else {
        throw Exception('Failed to remove favorite');
      }
    } catch (e) {
      print("お気に入り削除エラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('お気に入りの削除に失敗しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('プロフィール'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 24.0),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.blue,
                                    width: 2,
                                  ),
                                ),
                                child: _profileImageUrl != null
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: _profileImageUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                          errorWidget: (context, url, error) => Center(
                                            child: Text(
                                              _profileIcon,
                                              style: TextStyle(fontSize: 50),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          _profileIcon,
                                          style: TextStyle(fontSize: 50),
                                        ),
                                      ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatColumn('フォロワー', _followersCount),
                            SizedBox(width: 32),
                            _buildStatColumn('フォロー中', _followingCount),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.0),
                  Card(
                    margin: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '自己紹介',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16.0),
                          TextField(
                            controller: _bioController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: '自己紹介',
                              border: OutlineInputBorder(),
                              hintText: '自己紹介を入力してください',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16.0),
                  Card(
                    margin: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '基本情報',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16.0),
                          TextField(
                            controller: _residenceController,
                            decoration: InputDecoration(
                              labelText: '居住地',
                              border: OutlineInputBorder(),
                              hintText: '例：東京都渋谷区',
                            ),
                          ),
                          SizedBox(height: 16.0),
                          TextField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '年齢',
                              border: OutlineInputBorder(),
                              hintText: '例：25',
                            ),
                          ),
                          SizedBox(height: 16.0),
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: InputDecoration(
                              labelText: '性別',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: '未選択',
                                child: Text('未選択'),
                              ),
                              ...['男性', '女性', 'その他'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ],
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedGender = newValue;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16.0),
                  Card(
                    margin: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '好み',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.0),
                          Text(
                            _preferences.join(', '),
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24.0),
                  Card(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'お気に入りレストラン',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          _isLoadingFavorites
                              ? Center(child: CircularProgressIndicator())
                              : _favoriteRestaurants.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Text('お気に入りレストランはまだありません。'),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: _favoriteRestaurants.length,
                                      itemBuilder: (context, index) {
                                        final restaurant = _favoriteRestaurants[index];
                                        return Card(
                                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          child: Padding(
                                            padding: EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  restaurant['name'] ?? '店舗名不明',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  restaurant['address'] ?? '住所不明',
                                                  style: TextStyle(color: Colors.grey[600]),
                                                ),
                                                SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.star, color: Colors.orange, size: 20),
                                                    SizedBox(width: 4),
                                                    Text('${restaurant['rating'] ?? 0.0}'),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      '(${restaurant['user_ratings_total'] ?? 0}件のレビュー)',
                                                      style: TextStyle(color: Colors.grey[600]),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                Align(
                                                  alignment: Alignment.bottomRight,
                                                  child: IconButton(
                                                    icon: Icon(Icons.favorite, color: Colors.red),
                                                    onPressed: () => _removeFavorite(restaurant['place_id']),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: buildCommonBottomNavigationBar(context, currentIndex: 2),
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }
} 