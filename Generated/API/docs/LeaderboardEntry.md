# LeaderboardEntry

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**rank** | **Int** |  | [optional] 
**scope** | **String** | Tipo da linha. Default \&quot;user\&quot; (retrocompat). | [optional] 
**name** | **String** |  | [optional] 
**xp** | **Int** |  | [optional] 
**streak** | **Int** | Apenas em scope&#x3D;user. Em scope&#x3D;university é 0. | [optional] 
**isCurrentUser** | **Bool** | scope&#x3D;user — true se for o user logado. scope&#x3D;university — true se o user logado pertence a essa faculdade.  | [optional] 
**initials** | **String** |  | [optional] 
**universityId** | **String** | Apenas em scope&#x3D;university. | [optional] 
**state** | **String** | Apenas em scope&#x3D;university (UF da instituição). | [optional] 
**city** | **String** | Apenas em scope&#x3D;university. | [optional] 
**studentCount** | **Int** | Apenas em scope&#x3D;university (alunos somados pra esse XP). | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


