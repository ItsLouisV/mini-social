// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'isar_message.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarMessageCollection on Isar {
  IsarCollection<IsarMessage> get isarMessages => this.collection();
}

const IsarMessageSchema = CollectionSchema(
  name: r'IsarMessage',
  id: 2123208272505019328,
  properties: {
    r'content': PropertySchema(
      id: 0,
      name: r'content',
      type: IsarType.string,
    ),
    r'conversationId': PropertySchema(
      id: 1,
      name: r'conversationId',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'id': PropertySchema(
      id: 3,
      name: r'id',
      type: IsarType.string,
    ),
    r'isDeleted': PropertySchema(
      id: 4,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'mediaDuration': PropertySchema(
      id: 5,
      name: r'mediaDuration',
      type: IsarType.long,
    ),
    r'mediaHeight': PropertySchema(
      id: 6,
      name: r'mediaHeight',
      type: IsarType.long,
    ),
    r'mediaUrlsJson': PropertySchema(
      id: 7,
      name: r'mediaUrlsJson',
      type: IsarType.string,
    ),
    r'mediaWidth': PropertySchema(
      id: 8,
      name: r'mediaWidth',
      type: IsarType.long,
    ),
    r'messageType': PropertySchema(
      id: 9,
      name: r'messageType',
      type: IsarType.string,
    ),
    r'replyToMessageId': PropertySchema(
      id: 10,
      name: r'replyToMessageId',
      type: IsarType.string,
    ),
    r'senderId': PropertySchema(
      id: 11,
      name: r'senderId',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 12,
      name: r'status',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 13,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'waveform': PropertySchema(
      id: 14,
      name: r'waveform',
      type: IsarType.string,
    )
  },
  estimateSize: _isarMessageEstimateSize,
  serialize: _isarMessageSerialize,
  deserialize: _isarMessageDeserialize,
  deserializeProp: _isarMessageDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'id': IndexSchema(
      id: -3268401673993471357,
      name: r'id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'id',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'conversationId': IndexSchema(
      id: 2945908346256754300,
      name: r'conversationId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'conversationId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _isarMessageGetId,
  getLinks: _isarMessageGetLinks,
  attach: _isarMessageAttach,
  version: '3.1.0+1',
);

int _isarMessageEstimateSize(
  IsarMessage object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.content.length * 3;
  bytesCount += 3 + object.conversationId.length * 3;
  bytesCount += 3 + object.id.length * 3;
  {
    final value = object.mediaUrlsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.messageType.length * 3;
  {
    final value = object.replyToMessageId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.senderId.length * 3;
  {
    final value = object.status;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.waveform;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _isarMessageSerialize(
  IsarMessage object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.content);
  writer.writeString(offsets[1], object.conversationId);
  writer.writeDateTime(offsets[2], object.createdAt);
  writer.writeString(offsets[3], object.id);
  writer.writeBool(offsets[4], object.isDeleted);
  writer.writeLong(offsets[5], object.mediaDuration);
  writer.writeLong(offsets[6], object.mediaHeight);
  writer.writeString(offsets[7], object.mediaUrlsJson);
  writer.writeLong(offsets[8], object.mediaWidth);
  writer.writeString(offsets[9], object.messageType);
  writer.writeString(offsets[10], object.replyToMessageId);
  writer.writeString(offsets[11], object.senderId);
  writer.writeString(offsets[12], object.status);
  writer.writeDateTime(offsets[13], object.updatedAt);
  writer.writeString(offsets[14], object.waveform);
}

IsarMessage _isarMessageDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarMessage(
    content: reader.readString(offsets[0]),
    conversationId: reader.readString(offsets[1]),
    createdAt: reader.readDateTime(offsets[2]),
    id: reader.readString(offsets[3]),
    isDeleted: reader.readBoolOrNull(offsets[4]) ?? false,
    mediaDuration: reader.readLongOrNull(offsets[5]),
    mediaHeight: reader.readLongOrNull(offsets[6]),
    mediaUrlsJson: reader.readStringOrNull(offsets[7]),
    mediaWidth: reader.readLongOrNull(offsets[8]),
    messageType: reader.readStringOrNull(offsets[9]) ?? 'text',
    replyToMessageId: reader.readStringOrNull(offsets[10]),
    senderId: reader.readString(offsets[11]),
    status: reader.readStringOrNull(offsets[12]),
    updatedAt: reader.readDateTime(offsets[13]),
    waveform: reader.readStringOrNull(offsets[14]),
  );
  return object;
}

P _isarMessageDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    case 6:
      return (reader.readLongOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readLongOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset) ?? 'text') as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readDateTime(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _isarMessageGetId(IsarMessage object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _isarMessageGetLinks(IsarMessage object) {
  return [];
}

void _isarMessageAttach(
    IsarCollection<dynamic> col, Id id, IsarMessage object) {}

extension IsarMessageByIndex on IsarCollection<IsarMessage> {
  Future<IsarMessage?> getById(String id) {
    return getByIndex(r'id', [id]);
  }

  IsarMessage? getByIdSync(String id) {
    return getByIndexSync(r'id', [id]);
  }

  Future<bool> deleteById(String id) {
    return deleteByIndex(r'id', [id]);
  }

  bool deleteByIdSync(String id) {
    return deleteByIndexSync(r'id', [id]);
  }

  Future<List<IsarMessage?>> getAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndex(r'id', values);
  }

  List<IsarMessage?> getAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'id', values);
  }

  Future<int> deleteAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'id', values);
  }

  int deleteAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'id', values);
  }

  Future<Id> putById(IsarMessage object) {
    return putByIndex(r'id', object);
  }

  Id putByIdSync(IsarMessage object, {bool saveLinks = true}) {
    return putByIndexSync(r'id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllById(List<IsarMessage> objects) {
    return putAllByIndex(r'id', objects);
  }

  List<Id> putAllByIdSync(List<IsarMessage> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'id', objects, saveLinks: saveLinks);
  }
}

extension IsarMessageQueryWhereSort
    on QueryBuilder<IsarMessage, IsarMessage, QWhere> {
  QueryBuilder<IsarMessage, IsarMessage, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension IsarMessageQueryWhere
    on QueryBuilder<IsarMessage, IsarMessage, QWhereClause> {
  QueryBuilder<IsarMessage, IsarMessage, QAfterWhereClause> isarIdEqualTo(
      Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: isarId,
        upper: isarId,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterWhereClause> isarIdNotEqualTo(
      Id isarId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterWhereClause> isarIdGreaterThan(
      Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterWhereClause> isarIdLessThan(
      Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterWhereClause> isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerIsarId,
        includeLower: includeLower,
        upper: upperIsarId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterWhereClause> idEqualTo(
      String id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'id',
        value: [id],
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterWhereClause> idNotEqualTo(
      String id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [],
              upper: [id],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [id],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [id],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [],
              upper: [id],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterWhereClause>
      conversationIdEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'conversationId',
        value: [conversationId],
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterWhereClause>
      conversationIdNotEqualTo(String conversationId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [],
              upper: [conversationId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [conversationId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [conversationId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'conversationId',
              lower: [],
              upper: [conversationId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension IsarMessageQueryFilter
    on QueryBuilder<IsarMessage, IsarMessage, QFilterCondition> {
  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> contentEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      contentGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> contentLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> contentBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'content',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      contentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> contentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> contentContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> contentMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'content',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'content',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'content',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      conversationIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      conversationIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      conversationIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      conversationIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'conversationId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      conversationIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      conversationIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      conversationIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'conversationId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      conversationIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'conversationId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      conversationIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      conversationIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'conversationId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> idLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> idStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> idEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> idContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> idMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'id',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> isarIdEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      isarIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> isarIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'isarId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaDurationIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'mediaDuration',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaDurationIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'mediaDuration',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaDurationEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaDuration',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaDurationGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mediaDuration',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaDurationLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mediaDuration',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaDurationBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mediaDuration',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaHeightIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'mediaHeight',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaHeightIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'mediaHeight',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaHeightEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaHeight',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaHeightGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mediaHeight',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaHeightLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mediaHeight',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaHeightBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mediaHeight',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaUrlsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'mediaUrlsJson',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaUrlsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'mediaUrlsJson',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaUrlsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaUrlsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaUrlsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mediaUrlsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaUrlsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mediaUrlsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaUrlsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mediaUrlsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaUrlsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'mediaUrlsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaUrlsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'mediaUrlsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaUrlsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'mediaUrlsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaUrlsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'mediaUrlsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaUrlsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaUrlsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaUrlsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'mediaUrlsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaWidthIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'mediaWidth',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaWidthIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'mediaWidth',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaWidthEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'mediaWidth',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaWidthGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'mediaWidth',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaWidthLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'mediaWidth',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      mediaWidthBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'mediaWidth',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      messageTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      messageTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      messageTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      messageTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'messageType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      messageTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      messageTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      messageTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      messageTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'messageType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      messageTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageType',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      messageTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'messageType',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      replyToMessageIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'replyToMessageId',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      replyToMessageIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'replyToMessageId',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      replyToMessageIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'replyToMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      replyToMessageIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'replyToMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      replyToMessageIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'replyToMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      replyToMessageIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'replyToMessageId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      replyToMessageIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'replyToMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      replyToMessageIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'replyToMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      replyToMessageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'replyToMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      replyToMessageIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'replyToMessageId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      replyToMessageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'replyToMessageId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      replyToMessageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'replyToMessageId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> senderIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      senderIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      senderIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> senderIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'senderId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      senderIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      senderIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      senderIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'senderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> senderIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'senderId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      senderIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'senderId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      senderIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'senderId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> statusIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'status',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      statusIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'status',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> statusEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      statusGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> statusLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> statusBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> statusContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> statusMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      waveformIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'waveform',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      waveformIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'waveform',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> waveformEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'waveform',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      waveformGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'waveform',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      waveformLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'waveform',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> waveformBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'waveform',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      waveformStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'waveform',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      waveformEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'waveform',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      waveformContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'waveform',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition> waveformMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'waveform',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      waveformIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'waveform',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterFilterCondition>
      waveformIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'waveform',
        value: '',
      ));
    });
  }
}

extension IsarMessageQueryObject
    on QueryBuilder<IsarMessage, IsarMessage, QFilterCondition> {}

extension IsarMessageQueryLinks
    on QueryBuilder<IsarMessage, IsarMessage, QFilterCondition> {}

extension IsarMessageQuerySortBy
    on QueryBuilder<IsarMessage, IsarMessage, QSortBy> {
  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy>
      sortByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByMediaDuration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaDuration', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy>
      sortByMediaDurationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaDuration', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByMediaHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaHeight', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByMediaHeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaHeight', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByMediaUrlsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaUrlsJson', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy>
      sortByMediaUrlsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaUrlsJson', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByMediaWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaWidth', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByMediaWidthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaWidth', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByMessageType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageType', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByMessageTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageType', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy>
      sortByReplyToMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToMessageId', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy>
      sortByReplyToMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToMessageId', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortBySenderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderId', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortBySenderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderId', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByWaveform() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'waveform', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> sortByWaveformDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'waveform', Sort.desc);
    });
  }
}

extension IsarMessageQuerySortThenBy
    on QueryBuilder<IsarMessage, IsarMessage, QSortThenBy> {
  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByConversationId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy>
      thenByConversationIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conversationId', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByMediaDuration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaDuration', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy>
      thenByMediaDurationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaDuration', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByMediaHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaHeight', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByMediaHeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaHeight', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByMediaUrlsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaUrlsJson', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy>
      thenByMediaUrlsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaUrlsJson', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByMediaWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaWidth', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByMediaWidthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaWidth', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByMessageType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageType', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByMessageTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageType', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy>
      thenByReplyToMessageId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToMessageId', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy>
      thenByReplyToMessageIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'replyToMessageId', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenBySenderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderId', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenBySenderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderId', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByWaveform() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'waveform', Sort.asc);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QAfterSortBy> thenByWaveformDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'waveform', Sort.desc);
    });
  }
}

extension IsarMessageQueryWhereDistinct
    on QueryBuilder<IsarMessage, IsarMessage, QDistinct> {
  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctByContent(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctByConversationId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conversationId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctById(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctByMediaDuration() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaDuration');
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctByMediaHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaHeight');
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctByMediaUrlsJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaUrlsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctByMediaWidth() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mediaWidth');
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctByMessageType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'messageType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctByReplyToMessageId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'replyToMessageId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctBySenderId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'senderId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctByStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<IsarMessage, IsarMessage, QDistinct> distinctByWaveform(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'waveform', caseSensitive: caseSensitive);
    });
  }
}

extension IsarMessageQueryProperty
    on QueryBuilder<IsarMessage, IsarMessage, QQueryProperty> {
  QueryBuilder<IsarMessage, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<IsarMessage, String, QQueryOperations> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content');
    });
  }

  QueryBuilder<IsarMessage, String, QQueryOperations> conversationIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conversationId');
    });
  }

  QueryBuilder<IsarMessage, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<IsarMessage, String, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarMessage, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<IsarMessage, int?, QQueryOperations> mediaDurationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaDuration');
    });
  }

  QueryBuilder<IsarMessage, int?, QQueryOperations> mediaHeightProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaHeight');
    });
  }

  QueryBuilder<IsarMessage, String?, QQueryOperations> mediaUrlsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaUrlsJson');
    });
  }

  QueryBuilder<IsarMessage, int?, QQueryOperations> mediaWidthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaWidth');
    });
  }

  QueryBuilder<IsarMessage, String, QQueryOperations> messageTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'messageType');
    });
  }

  QueryBuilder<IsarMessage, String?, QQueryOperations>
      replyToMessageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'replyToMessageId');
    });
  }

  QueryBuilder<IsarMessage, String, QQueryOperations> senderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'senderId');
    });
  }

  QueryBuilder<IsarMessage, String?, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<IsarMessage, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<IsarMessage, String?, QQueryOperations> waveformProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'waveform');
    });
  }
}
