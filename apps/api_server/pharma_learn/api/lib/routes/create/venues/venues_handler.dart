import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/venues
///
/// Lists training venues.
Future<Response> venuesListHandler(Request req) async {
  final supabase = RequestContext.supabase;

  final params = req.url.queryParameters;
  final isActive = params['is_active'];

  var query = supabase
      .from('training_venues')
      .select('id, name, location, capacity, facilities, is_active');

  if (isActive != null) {
    query = query.eq('is_active', isActive == 'true');
  }

  final venues = await query.order('name', ascending: true);

  return ApiResponse.ok(venues).toResponse();
}

/// GET /v1/venues/:id
Future<Response> venueGetHandler(Request req) async {
  final venueId = req.rawPathParameters[#id];
  final supabase = RequestContext.supabase;

  if (venueId == null || venueId.isEmpty) {
    throw ValidationException({'id': 'Venue ID is required'});
  }

  final venue = await supabase
      .from('training_venues')
      .select('*')
      .eq('id', venueId)
      .maybeSingle();

  if (venue == null) {
    throw NotFoundException('Venue not found');
  }

  return ApiResponse.ok(venue).toResponse();
}

/// POST /v1/venues
Future<Response> venueCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to create venues');
  }

  final name = requireString(body, 'name');

  final now = DateTime.now().toUtc().toIso8601String();

  final venue = await supabase
      .from('training_venues')
      .insert({
        'name': name,
        'location': body['location'],
        'capacity': body['capacity'],
        'facilities': body['facilities'],
        'is_active': true,
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  return ApiResponse.created(venue).toResponse();
}

/// PATCH /v1/venues/:id
Future<Response> venueUpdateHandler(Request req) async {
  final venueId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (venueId == null || venueId.isEmpty) {
    throw ValidationException({'id': 'Venue ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to update venues');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  for (final field in ['name', 'location', 'capacity', 'facilities', 'is_active']) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('training_venues')
      .update(updateData)
      .eq('id', venueId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/venues/:id
Future<Response> venueDeleteHandler(Request req) async {
  final venueId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (venueId == null || venueId.isEmpty) {
    throw ValidationException({'id': 'Venue ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to delete venues');
  }

  // Check for scheduled sessions
  final sessions = await supabase
      .from('training_sessions')
      .select('id')
      .eq('venue_id', venueId)
      .inFilter('status', ['scheduled', 'in_progress'])
      .limit(1);

  if (sessions.isNotEmpty) {
    throw ConflictException('Cannot delete venue with scheduled sessions');
  }

  await supabase.from('training_venues').delete().eq('id', venueId);

  return ApiResponse.noContent().toResponse();
}
