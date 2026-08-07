import 'package:isar/isar.dart';
import 'isar_message.dart';

part 'isar_profile.g.dart';

@collection
class IsarProfile {
  Id get isarId => fastHash(id);

  @Index(unique: true, replace: true)
  final String id;

  final String username;
  final String? fullName;
  final String? avatarUrl;
  final String? bio;
  final int followerCount;
  final int followingCount;
  final DateTime updatedAt;

  IsarProfile({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.bio,
    this.followerCount = 0,
    this.followingCount = 0,
    required this.updatedAt,
  });
}
