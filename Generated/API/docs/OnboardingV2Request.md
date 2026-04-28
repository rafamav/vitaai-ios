# OnboardingV2Request

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**goal** | **String** | P1 — objetivo macro | 
**inFaculdade** | **String** | P2 — status faculdade. Obrigatório exceto se goal&#x3D;REVALIDA | [optional] 
**semester** | **Int** | Obrigatório se inFaculdade&#x3D;yes. 1-8&#x3D;FACULDADE, 9-12&#x3D;INTERNATO | [optional] 
**university** | **String** | Display name da universidade | [optional] 
**universityId** | **String** | FK universities.id (preferido) | [optional] 
**universityLms** | **String** | Portal LMS: canvas|mannesoft|moodle|sigaa|totvs | [optional] 
**selectedSubjects** | [OnboardingV2RequestSelectedSubjectsInner] |  | [optional] 
**studyGoal** | **String** | Objetivo de estudo (Aprovar 1ª, Top 10%, etc) | [optional] 
**targetSpecialty** | **String** | Slug de medical_specialties (apenas goal&#x3D;RESIDENCIA) | [optional] 
**targetInstitutions** | **[String]** | Bancas-alvo (apenas goal&#x3D;RESIDENCIA) | [optional] 
**currentStage** | **String** | Etapa Revalida (apenas goal&#x3D;REVALIDA) | [optional] 
**focusAreas** | **[String]** | Áreas de foco (apenas goal&#x3D;REVALIDA) | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


