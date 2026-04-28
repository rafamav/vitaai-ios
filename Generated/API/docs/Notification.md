# Notification

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **String** |  | [optional] 
**type** | **String** | badge | flashcard | transcriptionReady | portal_announcement | portal_file_added | portal_assignment_added | portal_grade_posted | portal_update | portal_summary | [optional] 
**title** | **String** |  | [optional] 
**description** | **String** |  | [optional] 
**time** | **String** |  | [optional] 
**read** | **Bool** |  | [optional] 
**group** | **String** |  | [optional] 
**route** | **String** |  | [optional] 
**priority** | **String** |  | [optional] 
**createdAt** | **Date** |  | [optional] 
**source** | **String** | Portal slug (canvas, mannesoft, sigaa, ...) ou null para notif interna Vita. Usado pelo client pra renderizar icone do portal. Added 2026-04-27. | [optional] 
**subjectId** | **String** | Disciplina linkada (academic_subjects.id) — pra deep link na UI. Added 2026-04-27. | [optional] 
**metadata** | **[String: JSONValue]** | Payload self-contained com iconUrl + brandColor + portalDisplayName + extras (announcementId, fileId, courseId, etc). Resolved no momento da criacao. Added 2026-04-27. | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


