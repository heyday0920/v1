import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ReservationScreen extends StatefulWidget {
  final Map<String, dynamic> restaurant;

  ReservationScreen({required this.restaurant});

  @override
  _ReservationScreenState createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _numberOfPeople = 2;
  String _selectedCourse = '通常コース';
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;

  final List<String> _courseOptions = [
    '通常コース',
    '特別コース',
    'デザート付きコース',
    'ドリンク付きコース',
  ];

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveReservation() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/reservations'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': 'anonymous_user',
          'restaurant_id': widget.restaurant['id'],
          'reservation_date': '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
          'reservation_time': '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
          'number_of_people': _numberOfPeople,
          'course_type': _selectedCourse,
          'notes': _noteController.text,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('予約を受け付けました')),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Failed to save reservation');
      }
    } catch (e) {
      print('予約保存エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('予約の保存に失敗しました')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('予約'),
        backgroundColor: Colors.deepOrange,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.restaurant['name'] ?? 'レストラン名',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 24),
                  ListTile(
                    title: Text('日付'),
                    subtitle: Text(
                      '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
                    ),
                    trailing: Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context),
                  ),
                  ListTile(
                    title: Text('時間'),
                    subtitle: Text(_selectedTime.format(context)),
                    trailing: Icon(Icons.access_time),
                    onTap: () => _selectTime(context),
                  ),
                  ListTile(
                    title: Text('人数'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            if (_numberOfPeople > 1) {
                              setState(() {
                                _numberOfPeople--;
                              });
                            }
                          },
                        ),
                        Text(
                          '$_numberOfPeople人',
                          style: TextStyle(fontSize: 16),
                        ),
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              _numberOfPeople++;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text('コース'),
                    trailing: DropdownButton<String>(
                      value: _selectedCourse,
                      items: _courseOptions.map((String course) {
                        return DropdownMenuItem<String>(
                          value: course,
                          child: Text(course),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCourse = newValue;
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: '備考',
                      border: OutlineInputBorder(),
                      hintText: 'アレルギーや特別な要望など',
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: _saveReservation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      child: Text('予約する'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 