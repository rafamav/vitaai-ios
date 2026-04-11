# DashboardHeroCard

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**type** | **String** | Semantic type for analytics and routing. DO NOT use in client to decide label/cta/background — those come from their own fields. Clients should only branch on &#x60;type&#x60; for routing (e.g. grade_alert opens disciplineDetail).  | 
**label** | **String** | Short uppercase label rendered above the title (e.g. \&quot;PROVA\&quot;, \&quot;RISCO DE REPROVAR\&quot;). Fully server-driven so clients don&#39;t duplicate copy.  | 
**labelTone** | **String** | Semantic tone for the label color. Clients map this to their own design tokens (VitaColors on iOS, Compose colors on Android). Never send raw hex from backend — backend speaks semantics, clients speak pixels.  | 
**title** | **String** |  | 
**subtitle** | **String** |  | 
**pills** | [DashboardHeroCardPillsInner] |  | 
**action** | [**DashboardHeroCardAction**](DashboardHeroCardAction.md) |  | 
**urgency** | **Int** | 0-100, higher &#x3D; more urgent | 
**cta** | [**DashboardHeroCardCta**](DashboardHeroCardCta.md) |  | 
**backgroundImage** | [**DashboardHeroCardBackground**](DashboardHeroCardBackground.md) |  | 
**gradeAlertMeta** | [**GradeAlertMeta**](GradeAlertMeta.md) | Only present when type&#x3D;grade_alert. Exposes the weighted grade-risk model so clients can show the \&quot;why\&quot; and Vita (coach IA) can reason without confusing absolute scores with weighted performance.  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


