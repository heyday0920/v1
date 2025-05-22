from flask import Flask, request, jsonify, send_file, Response
from flask_cors import CORS
import mysql.connector
from datetime import datetime
import requests
import os
from dotenv import load_dotenv
import io
import json
import base64
from PIL import Image
import uuid

# 環境変数の読み込み
load_dotenv()

# Flaskアプリケーションの初期化
app = Flask(__name__)
CORS(app)

# Google Places API設定
GOOGLE_PLACES_API_KEY = os.getenv('GOOGLE_PLACES_API_KEY', 'AIzaSyCsHd6IiiR5znUgVGF6GBIpz1sjzohy_aY')

# データベース接続設定
db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': 'takumakimi0920!!',
    'database': 'restaurant_app_db'
}

def get_db_connection():
    try:
        return mysql.connector.connect(**db_config)
    except Exception as e:
        print(f"データベース接続エラー: {e}")
        return None

# ルートエンドポイント
@app.route('/')
def home():
    return "Restaurant App API is running"

# レビュー関連のエンドポイント
@app.route('/reviews', methods=['GET'])
def get_reviews():
    print("レビュー取得エンドポイントにアクセス")
    conn = None
    try:
        print("レビュー取得開始")
        conn = get_db_connection()
        if conn is None:
            print("データベース接続失敗")
            return jsonify({"error": "Failed to connect to database"}), 500
        
        cursor = conn.cursor(dictionary=True)
        print("データベース接続成功")

        # レビューを取得（ユーザー情報も結合）
        sql = """
            SELECT r.*, u.residence as user_location
            FROM reviews r
            LEFT JOIN user_profiles u ON r.user_id = u.user_id
            ORDER BY r.created_at DESC
            LIMIT 50
        """
        
        cursor.execute(sql)
        reviews = cursor.fetchall()
        print(f"取得したレビュー数: {len(reviews)}")

        # datetimeオブジェクトを文字列に変換
        for review in reviews:
            if 'created_at' in review and review['created_at']:
                review['created_at'] = review['created_at'].strftime('%Y-%m-%d %H:%M:%S')

        return jsonify(reviews)

    except Exception as e:
        print(f"レビュー取得エラー: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            cursor.close()
            conn.close()
            print("データベース接続を閉じました")

@app.route('/reviews', methods=['POST'])
def save_review():
    conn = None
    try:
        data = request.json
        user_id = data.get('user_id', 'anonymous_user')
        restaurant_id = data.get('restaurant_id')
        rating = data.get('rating')
        review_text = data.get('review_text')

        conn = get_db_connection()
        if conn is None:
            return jsonify({"error": "Failed to connect to database"}), 500
        cursor = conn.cursor()

        sql = """
            INSERT INTO reviews (user_id, restaurant_id, rating, review_text)
            VALUES (%s, %s, %s, %s)
        """
        cursor.execute(sql, (user_id, restaurant_id, rating, review_text))
        conn.commit()

        return jsonify({"message": "Review saved successfully"})

    except Exception as e:
        print("エラー:", e)
        if conn:
            conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            cursor.close()
            conn.close()

# プロフィール関連のエンドポイント
@app.route('/profile', methods=['POST'])
def save_profile():
    conn = None
    try:
        data = request.json
        user_id = data.get('user_id', 'anonymous_user')
        residence = data.get('residence')
        age = data.get('age')
        gender = data.get('gender')
        preferences = data.get('preferences', [])

        conn = get_db_connection()
        if conn is None:
            return jsonify({"error": "Failed to connect to database"}), 500
        cursor = conn.cursor()

        # プロフィール情報の保存
        sql = """
            INSERT INTO user_profiles (user_id, residence, age, gender)
            VALUES (%s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
            residence = VALUES(residence),
            age = VALUES(age),
            gender = VALUES(gender)
        """
        cursor.execute(sql, (user_id, residence, age, gender))

        # 既存の好みを削除
        cursor.execute("DELETE FROM user_preferences WHERE user_id = %s", (user_id,))

        # 新しい好みを保存
        for preference in preferences:
            cursor.execute(
                "INSERT INTO user_preferences (user_id, preference) VALUES (%s, %s)",
                (user_id, preference)
            )

        conn.commit()
        return jsonify({"message": "Profile saved successfully"})

    except Exception as e:
        print("エラー:", e)
        if conn:
            conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            cursor.close()
            conn.close()

@app.route('/profile/<user_id>', methods=['GET'])
def get_profile(user_id):
    conn = None
    try:
        conn = get_db_connection()
        if conn is None:
            return jsonify({"error": "Failed to connect to database"}), 500
        cursor = conn.cursor(dictionary=True)

        # プロフィール情報の取得
        cursor.execute("SELECT * FROM user_profiles WHERE user_id = %s", (user_id,))
        profile = cursor.fetchone()

        if not profile:
            return jsonify({"error": "Profile not found"}), 404

        # 好みの取得
        cursor.execute("SELECT preference FROM user_preferences WHERE user_id = %s", (user_id,))
        preferences = [row['preference'] for row in cursor.fetchall()]

        profile['preferences'] = preferences
        return jsonify(profile)

    except Exception as e:
        print("エラー:", e)
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            cursor.close()
            conn.close()

# 予約関連のエンドポイント
@app.route('/reservations', methods=['POST'])
def save_reservation():
    conn = None
    try:
        data = request.json
        user_id = data.get('user_id', 'anonymous_user')
        restaurant_id = data.get('restaurant_id')
        reservation_date = data.get('reservation_date')
        reservation_time = data.get('reservation_time')
        number_of_people = data.get('number_of_people')
        course_type = data.get('course_type')
        notes = data.get('notes')

        conn = get_db_connection()
        if conn is None:
            return jsonify({"error": "Failed to connect to database"}), 500
        cursor = conn.cursor()

        sql = """
            INSERT INTO reservations (
                user_id, restaurant_id, reservation_date, reservation_time,
                number_of_people, course_type, notes
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(sql, (
            user_id, restaurant_id, reservation_date, reservation_time,
            number_of_people, course_type, notes
        ))
        conn.commit()

        return jsonify({"message": "Reservation saved successfully"})

    except Exception as e:
        print("エラー:", e)
        if conn:
            conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            cursor.close()
            conn.close()

@app.route('/reservations/<user_id>', methods=['GET'])
def get_user_reservations(user_id):
    conn = None
    try:
        conn = get_db_connection()
        if conn is None:
            return jsonify({"error": "Failed to connect to database"}), 500
        cursor = conn.cursor(dictionary=True)

        sql = """
            SELECT * FROM reservations
            WHERE user_id = %s
            ORDER BY reservation_date DESC, reservation_time DESC
        """
        cursor.execute(sql, (user_id,))
        reservations = cursor.fetchall()

        return jsonify(reservations)

    except Exception as e:
        print("エラー:", e)
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            cursor.close()
            conn.close()

# 近隣のレストランを取得するエンドポイント
@app.route('/nearby_restaurants', methods=['POST', 'OPTIONS'])
def get_nearby_restaurants():
    if request.method == 'OPTIONS':
        return '', 200
        
    try:
        data = request.json
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        radius = data.get('radius', 1000)  # デフォルト1km
        type = data.get('type', 'restaurant')

        print(f"近隣レストラン検索: 緯度={latitude}, 経度={longitude}, 半径={radius}m")
        print(f"使用するAPIキー: {GOOGLE_PLACES_API_KEY[:10]}...")

        # Google Places APIを使用して近隣のレストランを検索
        url = f'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        params = {
            'location': f'{latitude},{longitude}',
            'radius': radius,
            'type': type,
            'key': GOOGLE_PLACES_API_KEY,
            'fields': 'place_id,name,vicinity,rating,user_ratings_total,photos,geometry'
        }

        response = requests.get(url, params=params)
        data = response.json()

        if data['status'] == 'OK':
            restaurants = []
            for place in data['results']:
                # 複数の画像のphoto_referenceを取得
                photo_references = []
                if 'photos' in place and len(place['photos']) > 0:
                    photo_references = [photo.get('photo_reference') for photo in place['photos'][:5]]  # 最大5枚まで

                restaurant = {
                    'id': place['place_id'],
                    'place_id': place['place_id'],
                    'name': place.get('name', ''),
                    'address': place.get('vicinity', ''),
                    'rating': place.get('rating', 0),
                    'user_ratings_total': place.get('user_ratings_total', 0),
                    'photo_references': photo_references,  # 複数の画像参照を保存
                    'latitude': place['geometry']['location']['lat'],
                    'longitude': place['geometry']['location']['lng']
                }
                restaurants.append(restaurant)
            return jsonify(restaurants)
        else:
            error_message = f"Google Places API エラー: {data['status']}"
            if 'error_message' in data:
                error_message += f" - {data['error_message']}"
            return jsonify({"error": error_message}), 500

    except Exception as e:
        print(f"近隣レストラン取得エラー: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/place_photos', methods=['GET'])
def get_place_photos():
    try:
        photo_reference = request.args.get('photo_references[]')
        if not photo_reference:
            return jsonify({'error': 'Photo reference is required'}), 400

        api_key = os.getenv('GOOGLE_PLACES_API_KEY')
        url = f'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference={photo_reference}&key={api_key}'
        
        response = requests.get(url, stream=True, timeout=30)
        
        if response.status_code == 200:
            return Response(
                response.iter_content(chunk_size=1024),
                content_type=response.headers['Content-Type'],
                direct_passthrough=True
            )
        else:
            return jsonify({'error': 'Failed to fetch image from Google Places API'}), 500

    except Exception as e:
        print(f"レストラン画像取得エラー: {str(e)}")
        return jsonify({'error': str(e)}), 500

# お気に入り関連のエンドポイント
@app.route('/favorites', methods=['POST'])
def add_favorite():
    conn = None
    try:
        data = request.json
        user_id = data.get('user_id', 'anonymous_user')
        restaurant = data.get('restaurant')

        if not restaurant or 'place_id' not in restaurant:
            return jsonify({"error": "Invalid restaurant data"}), 400

        conn = get_db_connection()
        if conn is None:
            return jsonify({"error": "Failed to connect to database"}), 500
        cursor = conn.cursor()

        # お気に入りを保存
        sql = """
            INSERT INTO favorites (user_id, place_id, restaurant_data)
            VALUES (%s, %s, %s)
            ON DUPLICATE KEY UPDATE
            restaurant_data = VALUES(restaurant_data)
        """
        cursor.execute(sql, (
            user_id,
            restaurant['place_id'],
            json.dumps(restaurant)
        ))
        conn.commit()

        return jsonify({"message": "Favorite added successfully"})

    except Exception as e:
        print("エラー:", e)
        if conn:
            conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            cursor.close()
            conn.close()

@app.route('/favorites/<user_id>', methods=['GET'])
def get_favorites(user_id):
    conn = None
    try:
        conn = get_db_connection()
        if conn is None:
            return jsonify({"error": "Failed to connect to database"}), 500
        cursor = conn.cursor(dictionary=True)

        # お気に入りを取得
        cursor.execute("SELECT restaurant_data FROM favorites WHERE user_id = %s", (user_id,))
        favorites = cursor.fetchall()

        # JSONデータをパース
        restaurants = []
        for favorite in favorites:
            try:
                restaurant = json.loads(favorite['restaurant_data'])
                restaurants.append(restaurant)
            except json.JSONDecodeError as e:
                print(f"JSONデコードエラー: {e}")
                continue

        return jsonify(restaurants)

    except Exception as e:
        print("エラー:", e)
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            cursor.close()
            conn.close()

@app.route('/favorites/<user_id>/<place_id>', methods=['DELETE'])
def remove_favorite(user_id, place_id):
    conn = None
    try:
        conn = get_db_connection()
        if conn is None:
            return jsonify({"error": "Failed to connect to database"}), 500
        cursor = conn.cursor()

        # お気に入りを削除
        cursor.execute(
            "DELETE FROM favorites WHERE user_id = %s AND place_id = %s",
            (user_id, place_id)
        )
        conn.commit()

        return jsonify({"message": "Favorite removed successfully"})

    except Exception as e:
        print("エラー:", e)
        if conn:
            conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            cursor.close()
            conn.close()

# プロフィール画像の保存ディレクトリ
PROFILE_IMAGES_DIR = 'profile_images'
if not os.path.exists(PROFILE_IMAGES_DIR):
    os.makedirs(PROFILE_IMAGES_DIR)

@app.route('/upload_profile_image', methods=['POST'])
def upload_profile_image():
    try:
        data = request.json
        user_id = data.get('user_id', 'anonymous_user')
        image_data = data.get('image_data')

        if not image_data:
            return jsonify({"error": "No image data provided"}), 400

        # Base64デコード
        image_bytes = base64.b64decode(image_data)
        
        # 画像を開いてリサイズ
        image = Image.open(io.BytesIO(image_bytes))
        image = image.resize((200, 200), Image.Resampling.LANCZOS)
        
        # ファイル名を生成（ユニークなID + .jpg）
        filename = f"{uuid.uuid4()}.jpg"
        filepath = os.path.join(PROFILE_IMAGES_DIR, filename)
        
        # 画像を保存
        image.save(filepath, 'JPEG', quality=85)
        
        # 画像URLを生成
        image_url = f"/profile_image/{filename}"
        
        # データベースに画像URLを保存
        conn = get_db_connection()
        if conn is None:
            return jsonify({"error": "Failed to connect to database"}), 500
            
        cursor = conn.cursor()
        sql = """
            UPDATE user_profiles 
            SET profile_image_url = %s 
            WHERE user_id = %s
        """
        cursor.execute(sql, (image_url, user_id))
        conn.commit()
        
        return jsonify({
            "message": "Profile image uploaded successfully",
            "image_url": image_url
        })

    except Exception as e:
        print(f"プロフィール画像アップロードエラー: {str(e)}")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            cursor.close()
            conn.close()

@app.route('/profile_image/<filename>')
def get_profile_image(filename):
    try:
        filepath = os.path.join(PROFILE_IMAGES_DIR, filename)
        if not os.path.exists(filepath):
            return jsonify({"error": "Image not found"}), 404
            
        return send_file(
            filepath,
            mimetype='image/jpeg',
            cache_timeout=31536000  # 1年間のキャッシュ
        )
    except Exception as e:
        print(f"プロフィール画像取得エラー: {str(e)}")
        return jsonify({"error": str(e)}), 500

# データベースのテーブル定義を更新
def update_database_schema():
    conn = None
    try:
        conn = get_db_connection()
        if conn is None:
            return
            
        cursor = conn.cursor()
        
        # user_profilesテーブルに新しいカラムを追加
        try:
            cursor.execute("""
                ALTER TABLE user_profiles 
                ADD COLUMN profile_image_url VARCHAR(255)
            """)
        except mysql.connector.Error as err:
            if err.errno == 1060:  # Duplicate column error
                print("profile_image_urlカラムは既に存在します")
            else:
                raise err

        try:
            cursor.execute("""
                ALTER TABLE user_profiles 
                ADD COLUMN followers_count INT DEFAULT 0
            """)
        except mysql.connector.Error as err:
            if err.errno == 1060:  # Duplicate column error
                print("followers_countカラムは既に存在します")
            else:
                raise err

        try:
            cursor.execute("""
                ALTER TABLE user_profiles 
                ADD COLUMN following_count INT DEFAULT 0
            """)
        except mysql.connector.Error as err:
            if err.errno == 1060:  # Duplicate column error
                print("following_countカラムは既に存在します")
            else:
                raise err
        
        conn.commit()
        
    except Exception as e:
        print(f"データベーススキーマ更新エラー: {str(e)}")
        if conn:
            conn.rollback()
    finally:
        if conn:
            cursor.close()
            conn.close()

# アプリケーション起動時にデータベーススキーマを更新
update_database_schema()

if __name__ == '__main__':
    print("サーバーを起動します...")
    app.run(debug=True, host='0.0.0.0', port=5000) 