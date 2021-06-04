import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _storage = FirebaseStorage.instance;
  final _collection = FirebaseFirestore.instance.collection("myPhotos");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Firebase Storage"),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: IconButton(
        icon: Icon(
          Icons.add,
          size: 30,
          color: Colors.blue,
        ),
        onPressed: () => uploadImage(),
      ),
      body: Container(
        child: StreamBuilder<QuerySnapshot>(
          stream: _collection.orderBy("photo", descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: Text("Error: ${snapshot.error}"),
              );
            }
            if (snapshot.connectionState == ConnectionState.active) {
              if (snapshot.hasData) {
                return _buildList(snapshot.data!.docs);
              } else {
                return Center(child: Text("No Data Found"));
              }
            }
            return Center(
              child: CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
  }

  _buildList(List<QueryDocumentSnapshot<Object?>> listPhotos) {
    return ListView.builder(
      itemCount: listPhotos.length,
      itemBuilder: (context, index) {
        return InkWell(
          onLongPress: () =>
              _buildAlertDialog(context, image: listPhotos[index]),
          child: Container(
            padding: EdgeInsets.all(10),
            width: double.infinity,
            child: Image.network(
              listPhotos[index].get("photo"),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  _buildAlertDialog(BuildContext context,
      {required QueryDocumentSnapshot<Object?> image}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Delete"),
          content: Text("Do you want to delete this image?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("No"),
            ),
            TextButton(
              onPressed: () {
                String _imageUrl = image.get("photo");
                FirebaseFirestore.instance
                    .doc(image.reference.path)
                    .delete()
                    .then((value) {
                  _storage.refFromURL(_imageUrl).delete();
                });
                Navigator.pop(context);
              },
              child: Text("Yes"),
            ),
          ],
        );
      },
    );
  }

  uploadImage() async {
    final _imagePicker = ImagePicker();
    PickedFile image;
    // check permission
    await Permission.photos.request();

    var permissionStatus = await Permission.photos.status;
    if (permissionStatus.isGranted) {
      // select image
      image = (await _imagePicker.getImage(source: ImageSource.gallery))!;
      if (image.path.length > 0) {
        var file = File(image.path);
        // upload image to firebase
        var snapshot = await _storage
            .ref()
            .child("myPhoto/${Timestamp.now().microsecondsSinceEpoch}")
            .putFile(file)
            .then((e) => e);
        String downloadUrl = await snapshot.ref.getDownloadURL();
        FirebaseFirestore.instance
            .collection("myPhotos")
            .add({"photo": downloadUrl});
      } else {
        print("No image selected");
      }
    } else {
      print("Grant permission and try again.");
    }
  }
}
