# TrabalhoItem

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **String** |  | 
**title** | **String** | Verbatim title from portal/extractor (e.g. \&quot;AD1 — Curso PNAISARI\&quot;). Never synthesized. | 
**subjectName** | **String** |  | 
**type** | **String** | Category classification. Extractor writes this from LLM &#x60;kind&#x60; field. See src/lib/portal/extraction-prompts.ts. | 
**status** | **String** |  | 
**submitted** | **Bool** | True when student turned it in. Canvas syncs this automatically. | 
**submittedAt** | **Date** |  | [optional] 
**date** | **Date** | Deadline. Used to derive overdue/urgent states. | [optional] 
**daysUntil** | **Int** |  | [optional] 
**pointsPossible** | **Double** |  | [optional] 
**score** | **Double** |  | [optional] 
**grade** | **String** |  | [optional] 
**description** | **String** |  | [optional] 
**descriptionHtml** | **String** |  | [optional] 
**submissionTypes** | **[String]** |  | 
**canvasAssignmentId** | **String** |  | [optional] 
**canGenerate** | **Bool** |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


