# DashboardHeroCard

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**type** | **String** | Semantic bucket of the card. &#39;exam&#39; is used for any evaluation (including assignment/quiz/seminar/participation) — the differentiation lives in &#x60;label&#x60;.  | 
**label** | **String** | Human-readable category label. For evaluation cards matches the source evaluation&#39;s type: PROVA/TRABALHO/QUIZ/APRESENTAÇÃO/PARTICIPAÇÃO. For other card types: REVISÃO, STREAK, etc.  | [optional] 
**labelTone** | **String** | Visual tone of the label pill. danger&#x3D;overdue soon (&lt;&#x3D;3d), warning&#x3D;normal upcoming, info&#x3D;informational. | [optional] 
**title** | **String** |  | 
**subtitle** | **String** |  | 
**pills** | [DashboardHeroCardPillsInner] |  | 
**action** | [**DashboardHeroCardAction**](DashboardHeroCardAction.md) |  | 
**urgency** | **Int** | 0-100, higher &#x3D; more urgent | 
**cta** | [**DashboardHeroCardCta**](DashboardHeroCardCta.md) |  | 
**backgroundImage** | [**DashboardHeroCardBackgroundImage**](DashboardHeroCardBackgroundImage.md) |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


