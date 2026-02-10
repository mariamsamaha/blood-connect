// lib/services/database_service.dart

import 'package:postgres/postgres.dart';

class DatabaseService {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  
  Connection? _connection;

  DatabaseService({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
  });

  Future<Connection> _getConnection() async {
    if (_connection == null) {
      _connection = await Connection.open(
        Endpoint(
          host: host,
          port: port,
          database: database,
          username: username,
          password: password,
        ),
        settings: ConnectionSettings(sslMode: SslMode.disable),
      );
    }
    return _connection!;
  }

  Future<List<Map<String, dynamic>>> query(
    String sql, {
    Map<String, dynamic>? params,
  }) async {
    final conn = await _getConnection();
    final result = await conn.execute(
      Sql.named(sql),
      parameters: params ?? {},
    );
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<void> close() async {
    await _connection?.close();
  }
}