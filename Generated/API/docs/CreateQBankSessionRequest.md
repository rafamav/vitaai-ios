# CreateQBankSessionRequest

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**questionCount** | **Int** |  | [optional] 
**institutionIds** | **[Int]** |  | [optional] 
**years** | **[Int]** |  | [optional] 
**difficulties** | **[String]** |  | [optional] 
**topicIds** | **[Int]** |  | [optional] 
**subjectIds** | **[String]** | [PREFERRED 2026-04-17b] Filter questions by the student&#39;s academic_subjects.id. Backend resolves each subjectId → disciplineSlug (via academic_subjects.disciplineSlug or fuzzy match on canonicalName) and filters qbank_questions accordingly. This is the SOT path — client should pass subjects the student is actually enrolled in, not catalog slugs.  | [optional] 
**disciplineSlugs** | **[String]** | [DEPRECATED] Direct filter by MedSimple catalog slug. Kept for fallback when student has no academic_subjects (no portal connected yet). Prefer subjectIds.  | [optional] 
**lens** | **String** | Lente aplicada na sessão (tradicional/pbl/great-areas). Backend usa pra determinar qual coluna &#x60;groupSlugs[]&#x60; consulta. Added 2026-04-28. | [optional] 
**pblSystemSlugs** | **[String]** | Filtra qbank_questions.pblSystemSlug IN (...). Usado quando lens&#x3D;pbl. Added 2026-04-28. | [optional] 
**examGreatAreaSlugs** | **[String]** | Filtra qbank_questions.examGreatAreaSlug IN (...). Usado quando lens&#x3D;great-areas. Added 2026-04-28. | [optional] 
**format** | **[String]** | Filtro de formato. objective/discursive/withImage. Added 2026-04-28. | [optional] 
**hideAnswered** | **Bool** | Oculta Q já respondidas pelo user. Added 2026-04-28. | [optional] 
**hideAnnulled** | **Bool** | Oculta Q anuladas (isCancelled&#x3D;true). Added 2026-04-28. | [optional] 
**hideReviewed** | **Bool** | Oculta Q em listas de revisão. Added 2026-04-28. | [optional] 
**onlyResidence** | **Bool** |  | [optional] 
**stage** | **String** |  | [optional] 
**onlyUnanswered** | **Bool** |  | [optional] 
**title** | **String** |  | [optional] 
**excludeNoExplanation** | **Bool** | Quality filter — drop questions com explanation NULL ou length&lt;&#x3D;50 chars. Default true client-side. Added 2026-04-27.  | [optional] 
**includeSynthetic** | **Bool** | Quality filter — when false, drop LLM-generated questions (isSynthetic&#x3D;true; year&gt;&#x3D;2025, source&#x3D;medsimple). Default true. Added 2026-04-27.  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


