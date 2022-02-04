//NO DOCUMENT
/**
 * @brief      API para la insercion de errores
 * @details    Metodos para insertar registros en un objeto ante alguna excepcion para poder tener mayor detalle del error y realizar seguimiento de los mismos
 */
public class ErrorService {

    /**
     * @brief       Metodo para insertar un error en la base
     * @details     Dado una excepcion de cualquier tipo el metodo genera un nuevo registro de Error Log con todos los datos de la excepcion,
     *              la informacion que completa es el numero de linea, mensaje del error, stack trace, el tipo de excepcion y el Id del usuario logueado.
     * @version     10.0
     * @param       except    excepcion que se quiere insertar
     * @return      Void
     * @code{.java}
     *      try{
     *          insert new Account(Name = 'Test Account');
     *      }catch(Exception e){
     *          FieloEE.ErrorService.insertError(e);
     *      }
     * @endcode
     */
    public static void insertError(Exception except){
        FieloPLT__ErrorLog__c error = new FieloPLT__ErrorLog__c();

        error.FieloPLT__LineNumber__c = except.getLineNumber();
        error.FieloPLT__Message__c = except.getMessage();
        error.FieloPLT__StackTrace__c = except.getStackTraceString();
        error.FieloPLT__Type__c = except.getTypeName();
        error.FieloPLT__UserId__c = UserInfo.getUserId();

        insert error;
    }

    /**
    * @details Method that insert the error log
    */
    public static void insertError(DMLException e){
        FieloPLT__ErrorLog__c error = new FieloPLT__ErrorLog__c();

        error.FieloPLT__LineNumber__c = e.getLineNumber();
        error.FieloPLT__Message__c = e.getDMLMessage(0);
        error.FieloPLT__StackTrace__c = e.getStackTraceString();
        error.FieloPLT__Type__c = e.getTypeName();
        error.FieloPLT__UserId__c = UserInfo.getUserId();

        insert error;
    }


    public static void insertErrors(List<Database.Error> errors){
        List<FieloPLT__ErrorLog__c> errorList = new List<FieloPLT__ErrorLog__c>();
        for (Database.Error e : errors) {
            errorList.add(
                new FieloPLT__ErrorLog__c(
                    FieloPLT__Message__c = e.getMessage(),
                    FieloPLT__Type__c = 'Database.Error: ' + e.getStatusCode(),
                    FieloPLT__UserId__c = UserInfo.getUserId()
                )
            );
        }

        if(!errorList.isEmpty()){
            insert errorList;
        }
    }
}