# QBankPreviewRequest

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**lens** | **String** |  | [optional] 
**groupSlugs** | **[String]** | Slugs do agrupamento atual (disciplines/pbl_systems/exam_great_areas conforme lens). | [optional] 
**institutionIds** | **[Int]** |  | [optional] 
**years** | [**QBankPreviewRequestYears**](QBankPreviewRequestYears.md) |  | [optional] 
**difficulties** | **[String]** |  | [optional] 
**format** | **[String]** | Filtro de formato. objective/discursive/withImage podem combinar. | [optional] 
**hideAnswered** | **Bool** | Oculta Q já respondidas pelo user. | [optional] 
**hideAnnulled** | **Bool** | Oculta Q anuladas (isCancelled&#x3D;true). | [optional] 
**hideReviewed** | **Bool** | Oculta Q em listas de revisão do user. | [optional] 
**excludeNoExplanation** | **Bool** | Default true client-side. Drop Q sem comentário substancial. | [optional] 
**includeSynthetic** | **Bool** | Default false. Se false, exclui Q geradas por IA (isSynthetic&#x3D;true). | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


