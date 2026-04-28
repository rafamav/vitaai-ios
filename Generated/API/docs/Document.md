# Document

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **String** |  | [optional] 
**title** | **String** |  | [optional] 
**fileName** | **String** |  | [optional] 
**fileUrl** | **String** |  | [optional] 
**subjectId** | **String** |  | [optional] 
**totalPages** | **Int** |  | [optional] 
**currentPage** | **Int** |  | [optional] 
**readProgress** | **Double** |  | [optional] 
**isFavorite** | **Bool** |  | [optional] 
**createdAt** | **Date** |  | [optional] 
**portalCreatedAt** | **Date** | Data REAL de upload do material no portal (Canvas/WebAluno), distinta de &#x60;createdAt&#x60; que é o timestamp do nosso sync. Quando ausente (docs antigos sincronizados antes do feature), UI faz fallback para &#x60;createdAt&#x60;.  | [optional] 
**portalModifiedAt** | **Date** | Última modificação do material no portal de origem. | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


