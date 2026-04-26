# QBankSession

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **String** |  | [optional] 
**title** | **String** |  | [optional] 
**questionCount** | **Int** |  | [optional] 
**totalQuestions** | **Int** |  | [optional] 
**currentIndex** | **Int** |  | [optional] 
**answeredCount** | **Int** |  | [optional] 
**answeredQuestions** | **Int** |  | [optional] 
**correctCount** | **Int** |  | [optional] 
**correctAnswers** | **Int** |  | [optional] 
**score** | **Double** |  | [optional] 
**createdAt** | **Date** |  | [optional] 
**finishedAt** | **Date** |  | [optional] 
**disciplineTitle** | **String** | Discipline label to display in the \&quot;Sessões Recentes\&quot; cell. Either the user&#39;s filter when the session was created, or the first topic&#39;s discipline slug. Added 2026-04-17.  | [optional] 
**topicTitle** | **String** | Topic label to display in the \&quot;Sessões Recentes\&quot; cell. Either the first filter topic&#39;s title, or the first question&#39;s first topic title. Added 2026-04-17.  | [optional] 
**disciplineTitles** | **[String]** | Full list of discipline labels the session was scoped to (derived from &#x60;filters.disciplineSlugs&#x60; at creation time). The session &#x60;title&#x60; is a compact \&quot;First +N\&quot; summary for display; this field is the source of truth when the client needs every discipline. Added 2026-04-17b.  | [optional] 
**questionIds** | **[Int]** | Ordered list of question IDs for this session. Returned only by POST /api/qbank/sessions (session creation). Not persisted or returned by GET — clients must cache locally after creation. Added 2026-04-19 to support Android QBank session navigation.  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


