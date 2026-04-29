# QBankPreviewResponse

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**total** | **Int** | Quantas Q batem com TODOS os filtros aplicados. | 
**byDifficulty** | **[String: Int]** | Breakdown por dificuldade (easy/medium/hard). | [optional] 
**byYear** | **[String: Int]** | Top 10 anos com mais Q dentro do filtro. | [optional] 
**topGroups** | [QBankPreviewResponseTopGroupsInner] | Top 5 grupos (disciplines/systems/areas) dentro do filtro. | [optional] 
**appliedJourneyBoost** | **String** | Echo do journeyType usado pra ranking automático (debug-friendly). | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


