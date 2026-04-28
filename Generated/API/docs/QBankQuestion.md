# QBankQuestion

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **Int** |  | [optional] 
**statement** | **String** |  | [optional] 
**year** | **Int** |  | [optional] 
**difficulty** | **String** |  | [optional] 
**institutionName** | **String** |  | [optional] 
**alternatives** | [QBankQuestionAlternativesInner] |  | [optional] 
**images** | **[JSONValue]** |  | [optional] 
**topics** | **[JSONValue]** |  | [optional] 
**statistics** | **JSONValue** |  | [optional] 
**userAnswer** | **JSONValue** |  | [optional] 
**medevoSlug** | **String** | Slug original MedEvo (cross-match Vita x MedEvo). Rastreia origem cursinho. Added 2026-04-27. | [optional] 
**medevoArea** | **String** | Area cursinho-style MedEvo (7 valores). Tag PARALELA a arvore canonica BYMAV. Mapeada para examArea INEP via vita.exam_area_mapping. Added 2026-04-27. | [optional] 
**medevoTopic** | **String** | Topic granular MedEvo (~169 valores). Tag PARALELA. Added 2026-04-27. | [optional] 
**medevoSubtopic** | **String** | Subtopic ultra-granular MedEvo (~799 valores). Tag PARALELA. Added 2026-04-27. | [optional] 
**examGreatAreaSlug** | **String** | Grande área CNRM/Enare (5 fixas). Derivada de disciplineSlug e/ou medevoArea via mapping declarativo. Usada por Jornada-com-objetivo (Residência/ENAMED/Revalida) e modo great-areas do toggle 3 lentes. SOT da decisão: agent-brain/decisions/2026-04-27_jornada-3lentes-FINAL.md Cobertura atual: 88.8% das Q reais (não-sintéticas). Updated 2026-04-27.  | [optional] 
**pblSystemSlug** | **String** | Sistema PBL (12 fixos). Derivada de disciplineSlug via mapping declarativo. Usada pelo modo PBL do toggle 3 lentes (faculdades modulares: UFRN, FAMETRO, USP-RP, UFOP, CESUPA). Cobertura atual: 77.1% das Q reais. Updated 2026-04-27.  | [optional] 
**isSynthetic** | **Bool** | true se Q gerada (sem institutionId + year&gt;&#x3D;2025 + source&#x3D;medsimple). false se prova real. Filtrar isSynthetic&#x3D;false para Jornada-com-objetivo. Added 2026-04-27. | [optional] [default to false]
**matchConfidence** | **Float** | Confianca cross-match MedEvo. 1.0&#x3D;exato fingerprint SHA1 normalizado, 0.85-0.99&#x3D;fuzzy MinHash+LSH, null&#x3D;sem match. Added 2026-04-27. | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


