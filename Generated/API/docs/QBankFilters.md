# QBankFilters

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**lens** | **String** | Lente aplicada na resposta atual. Echo do query param OU profile.contentOrganizationMode. Added 2026-04-28. | [optional] 
**groups** | [QBankFiltersGroupsInner] | Agrupamento de Q conforme &#x60;lens&#x60;. Substitui &#x60;disciplines&#x60; (deprecated) como filtro principal de UI. Cada item tem slug + name + count global. - tradicional: vita.disciplines (96 itens) - pbl: vita.pbl_systems (12 itens) - great-areas: vita.exam_great_areas (5 itens) Ordenado por count desc. Added 2026-04-28.  | [optional] 
**institutions** | [QBankFiltersInstitutionsInner] |  | [optional] 
**topics** | [QBankFiltersTopicsInner] |  | [optional] 
**disciplines** | [QBankFiltersDisciplinesInner] | [DEPRECATED 2026-04-17b] Catalog view from qbank_topics.disciplineSlug + vita.disciplines. Use GET /api/subjects instead — QBank must filter by the student&#39;s actual enrolled subjects, not the universal MedSimple catalog. This field stays for fallback during iOS/Android migration and may be removed in 2026-05.  | [optional] 
**years** | [QBankFiltersYearsInner] |  | [optional] 
**difficulties** | [QBankFiltersDifficultiesInner] |  | [optional] 
**totalQuestions** | **Int** |  | [optional] 
**totalAllStages** | **Int** |  | [optional] 
**stage** | **String** |  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


