({
    doInit : function(component, event, helper) {
        try{
            if (component.get('v.member') == null || component.get('v.member') == undefined) {
                var memberEvent = $A.get("e.FieloPLT:RefreshMemberEvent");
                if (memberEvent) {
                    memberEvent.fire();
                }
            }
        } catch(e) {
            console.log(e);
        }
    },
    updateMember: function(component, event, helper){
        try {
            var member = event.getParam('member');
            component.set('v.member', member);
            var pipsim = component.find('pipsim');
            pipsim && pipsim.handleMemberChange({member: member});
        } catch(e) {
            console.error(e);
        }
    }
})