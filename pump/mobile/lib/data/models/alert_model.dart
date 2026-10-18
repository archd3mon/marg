class TransitAlert {
  final String id;
  final String title; // 'Route 144 · Delay'
  final String timeAgo; // '8 min ago', '1 h ago', 'Today'
  final String body;
  final String type; // 'delay', 'diversion', 'commute'
  final String? routeLine; // '144', '17'
  final bool isSavedRoute;
  final bool isSample;

  const TransitAlert({
    required this.id,
    required this.title,
    required this.timeAgo,
    required this.body,
    required this.type,
    this.routeLine,
    this.isSavedRoute = true,
    this.isSample = false,
  });

  factory TransitAlert.fromJson(Map<String, dynamic> json) => TransitAlert(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        timeAgo: json['time_ago']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        type: json['type']?.toString() ?? 'delay',
        routeLine: json['route_line']?.toString(),
        isSavedRoute: json['is_saved_route'] as bool? ?? true,
        isSample: json['is_sample'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'time_ago': timeAgo,
        'body': body,
        'type': type,
        'route_line': routeLine,
        'is_saved_route': isSavedRoute,
        'is_sample': isSample,
      };
}
