# QBankProgress

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**totalAvailable** | **Int** |  | [optional] 
**totalAnswered** | **Int** |  | [optional] 
**totalCorrect** | **Int** |  | [optional] 
**totalAnswers** | **Int** |  | [optional] 
**accuracy** | **Double** |  | [optional] 
**byDifficulty** | **[JSONValue]** |  | [optional] 
**byTopic** | **[JSONValue]** |  | [optional] 
**scope** | **String** | \&quot;global\&quot; when totals reflect the whole catalogue (stage-scoped), \&quot;enrolled\&quot; when the &#x60;disciplineSlugs[]&#x60; query param was supplied. Added 2026-04-17.  | [optional] 
**scopedSlugs** | **[String]** | Echo of the &#x60;disciplineSlugs[]&#x60; query param used to filter this response. Empty array when &#x60;scope &#x3D; \&quot;global\&quot;&#x60;. Added 2026-04-17.  | [optional] 
**requestedSlugs** | **[String]** | Echo of the original &#x60;disciplineSlugs[]&#x60; query param BEFORE server-side resolution. Differs from &#x60;scopedSlugs&#x60; when enrolled slugs are resolved to canonical qbank slugs (e.g. anatomia-medica-i -&gt; anatomia). Added 2026-04-17c.  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


