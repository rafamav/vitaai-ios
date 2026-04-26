# AcademicSubject

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **String** |  | 
**name** | **String** |  | 
**displayName** | **String** | User-ownable display name (issue #170 phase A). UI shows displayName ?? name. Sync NEVER reads nor writes. PATCH via /api/subjects/{id} with {displayName: string|null}. Empty string and null both reset to the portal-canonical name.  | [optional] 
**status** | **String** |  | [optional] 
**source** | **String** |  | [optional] 
**difficulty** | **String** |  | [optional] 
**disciplineSlug** | **String** | FK-like link to vita.disciplines.slug for QBank/Simulado filtering. Nullable while the backfill job hasn&#39;t matched this subject to a catalog entry (fuzzy match on canonicalName).  | [optional] 
**canonicalName** | **String** |  | [optional] 
**professor** | **String** |  | [optional] 
**semester** | **String** |  | [optional] 
**workload** | **Int** |  | [optional] 
**area** | **String** | Catalog area (basica, clinica, cirurgica, etc.) joined from vita.disciplines. | [optional] 
**icon** | **String** | Icon slug from vita.disciplines, used for row rendering. | [optional] 
**needsReview** | **Bool** | True when the LLM normalizer couldn&#39;t place this subject in the 96-row catalog. | [optional] 
**questionCount** | **Int** | Total QBank questions available for this discipline slug (derived from qbank_topics join). | [optional] 
**attendance** | **Double** | Attendance percent copied from academic_subjects.attendancePercent. | [optional] 
**absences** | **Int** | Absence count copied from academic_subjects.absences. | [optional] 
**grade1** | **Double** | AP1/P1/N1 score derived from academic_evaluations (title regex). | [optional] 
**grade2** | **Double** | AP2/P2/N2 score derived from academic_evaluations (title regex). | [optional] 
**grade3** | **Double** | AP3/P3/N3 score derived from academic_evaluations (title regex). | [optional] 
**finalGrade** | **Double** | Final/Média/Exame score derived from academic_evaluations (title regex). | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


