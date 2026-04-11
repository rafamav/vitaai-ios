# GradeAlertMeta

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**riskCategory** | **String** | Which of the 3 categories triggered this alert | 
**scorePercent** | **Int** | % of max achieved on the triggering evaluation (score/weight*100). Only set when a single isolated eval triggered the alert.  | [optional] 
**projectedAvg** | **Double** | Projected final average assuming student scores exactly passingGrade on remaining evaluations. Neutral projection, not pessimistic.  | [optional] 
**pointsEarned** | **Double** | Sum of (score * weight) across all graded evaluations of this subject | 
**pointsRemaining** | **Double** | Weight of evaluations still to be taken (totalWeight - assessedWeight) | 
**minNeeded** | **Double** | Minimum average needed on remaining evaluations to reach passingGrade. Null when there are no remaining evaluations.  | [optional] 
**assessedWeight** | **Double** | Sum of weights of evaluations already graded (0-10) | 
**totalWeight** | **Double** | Total weight of all evaluations for the subject (ULBRA default &#x3D; 10) | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


