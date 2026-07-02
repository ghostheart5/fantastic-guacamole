import 'package:flutter/material.dart';

const double s4 = 4;
const double s8 = 8;
const double s12 = 12;
const double s16 = 16;
const double s20 = 20;
const double s24 = 24;
const double s32 = 32;

Widget vSpace(double value) => SizedBox(height: value);
Widget hSpace(double value) => SizedBox(width: value);

EdgeInsets hPad(double value) => EdgeInsets.symmetric(horizontal: value);
EdgeInsets vPad(double value) => EdgeInsets.symmetric(vertical: value);
EdgeInsets allPad(double value) => EdgeInsets.all(value);
