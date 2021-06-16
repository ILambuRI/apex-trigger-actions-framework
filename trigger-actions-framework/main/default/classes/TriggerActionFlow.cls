/*
   Copyright 2021 Google LLC

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

	https://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */

public inherited sharing class TriggerActionFlow implements TriggerAction.BeforeInsert, TriggerAction.AfterInsert, TriggerAction.BeforeUpdate, TriggerAction.AfterUpdate, TriggerAction.AfterUndelete {
	public String flowName;
	public Boolean allowRecursion;
	@testVisible
	private static final String INVALID_FLOW_NAME = 'You must provide the name of a flow to execute';
	@testVisible
	private static final String NEW_RECORD = 'Record';
	@testVisible
	private static final String OLD_RECORD = 'Record_Prior';
	@testVisible
	public static final String OBJECT_STRING = 'Object';
	public static final String APEX_STRING = 'Apex';
	public static final String FLOW_STRING = 'Flow';
	public static final String INVALID_BYPASS_REQUEST = 'You can only pass one request into {0}';
	public static final String INVALID_TYPE = 'The bypassType must equal Object, Apex, or Flow';
	public static final Set<String> REQUEST_TYPES = new Set<String>{
		OBJECT_STRING,
		APEX_STRING,
		FLOW_STRING
	};
	@TestVisible
	private static Set<String> bypassedFlows;

	static {
		bypassedFlows = new Set<String>();
	}

	public void beforeInsert(List<SObject> newList) {
		if (!thisFlowIsBypassed()) {
			Set<String> editableFields = getEditableFields(newList);
			for (sObject record : newList) {
				Flow.Interview myFlow = Flow.Interview.createInterview(
					flowName,
					new Map<String, Object>{ NEW_RECORD => record }
				);
				myFlow.start();
				System.debug(myFlow.getVariableValue(NEW_RECORD));
				applyFlowValues(
					record,
					(sObject) myFlow.getVariableValue(NEW_RECORD),
					editableFields
				);
			}
		}
	}

	public void afterInsert(List<SObject> newList) {
		if (!thisFlowIsBypassed()) {
			for (sObject record : newList) {
				Flow.Interview myFlow = Flow.Interview.createInterview(
					flowName,
					new Map<String, Object>{ NEW_RECORD => record }
				);
				myFlow.start();
			}
		}
	}

	public void beforeUpdate(List<SObject> newList, List<SObject> oldList) {
		if (!thisFlowIsBypassed()) {
			Map<Id, SObject> oldMap = new Map<Id, SObject>(oldList);
			Set<String> editableFields = getEditableFields(newList);
			for (sObject record : newList) {
				if (
					TriggerBase.idToNumberOfTimesSeenBeforeUpdate.get(record.id) == 1 ||
					(allowRecursion == true)
				) {
					Flow.Interview myFlow = Flow.Interview.createInterview(
						flowName,
						new Map<String, Object>{
							NEW_RECORD => record,
							OLD_RECORD => oldMap.get(record.Id)
						}
					);
					myFlow.start();
					applyFlowValues(
						record,
						(sObject) myFlow.getVariableValue(NEW_RECORD),
						editableFields
					);
				}
			}
		}
	}

	public void afterUpdate(List<SObject> newList, List<SObject> oldList) {
		if (!thisFlowIsBypassed()) {
			Map<Id, SObject> oldMap = new Map<Id, SObject>(oldList);
			Set<String> editableFields = getEditableFields(newList);
			for (sObject record : newList) {
				if (
					TriggerBase.idToNumberOfTimesSeenBeforeUpdate.get(record.id) == 1 ||
					(allowRecursion == true)
				) {
					Flow.Interview myFlow = Flow.Interview.createInterview(
						flowName,
						new Map<String, Object>{
							NEW_RECORD => record,
							OLD_RECORD => oldMap.get(record.Id)
						}
					);
					myFlow.start();
				}
			}
		}
	}

	public void beforeDelete(List<SObject> oldList) {
		if (!thisFlowIsBypassed()) {
			for (sObject record : oldList) {
				Flow.Interview myFlow = Flow.Interview.createInterview(
					flowName,
					new Map<String, Object>{ OLD_RECORD => record }
				);
				myFlow.start();
			}
		}
	}

	public void afterDelete(List<SObject> oldList) {
		if (!thisFlowIsBypassed()) {
			for (sObject record : oldList) {
				Flow.Interview myFlow = Flow.Interview.createInterview(
					flowName,
					new Map<String, Object>{ OLD_RECORD => record }
				);
				myFlow.start();
			}
		}
	}

	public void afterUndelete(List<SObject> newList) {
		if (!thisFlowIsBypassed()) {
			for (sObject record : newList) {
				Flow.Interview myFlow = Flow.Interview.createInterview(
					flowName,
					new Map<String, Object>{ NEW_RECORD => record }
				);
				myFlow.start();
			}
		}
	}

	public static void bypass(String flowName) {
		TriggerActionFlow.bypassedFlows.add(flowName);
	}

	public static void clearBypass(String flowName) {
		TriggerActionFlow.bypassedFlows.remove(flowName);
	}

	public static Boolean isBypassed(String flowName) {
		return TriggerActionFlow.bypassedFlows.contains(flowName);
	}

	public static void clearAllBypasses() {
		TriggerActionFlow.bypassedFlows.clear();
	}

	private Boolean thisFlowIsBypassed() {
		if (String.isBlank(flowName)) {
			throw new TriggerActionFlowException(INVALID_FLOW_NAME);
		}
		return TriggerActionFlow.isBypassed(flowName);
	}

	private Set<String> getEditableFields(List<SObject> newList) {
		Set<String> editableFields = new Set<String>();
		for (
			Schema.SObjectField fieldRef : newList[0]
				.getSObjectType()
				.getDescribe()
				.fields.getMap()
				.values()
		) {
			Schema.DescribeFieldResult fieldResult = fieldRef.getDescribe();
			if (fieldResult.isUpdateable()) {
				editableFields.add(fieldResult.getName());
			}
		}
		return editableFields;
	}

	private void applyFlowValues(
		SObject newRecord,
		SObject newRecordAfterFlow,
		Set<String> editableFields
	) {
		for (String fieldName : editableFields) {
			if (newRecord.get(fieldName) != newRecordAfterFlow.get(fieldName)) {
				newRecord.put(fieldName, newRecordAfterFlow.get(fieldName));
			}
		}
	}

	class TriggerActionFlowException extends Exception {
	}
}
