import 'package:flutter/material.dart';

class AlternatingColorListView extends StatelessWidget {
  final List<Widget> children;
  final Color evenColor;
  final Color oddColor;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const AlternatingColorListView({
    Key? key,
    required this.children,
    this.evenColor = Colors.white,
    this.oddColor = const Color(0xFFF5F5F5), // Light grey
    this.physics,
    this.shrinkWrap = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: children.length,
      physics: physics,
      shrinkWrap: shrinkWrap,
      itemBuilder: (context, index) {
        return Container(
          color: index % 2 == 0 ? evenColor : oddColor,
          child: children[index],
        );
      },
    );
  }
}