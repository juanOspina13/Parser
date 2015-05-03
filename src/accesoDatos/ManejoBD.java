/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

package accesoDatos;

/**
 *
 * @author juan
 */
 
 
import java.sql.*;
import java.util.LinkedList;
import java.util.Scanner;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.swing.JOptionPane;
import modelo.Dato;
import modelo.Funcion;
import parser.GUI.Funciones;
 
public class ManejoBD {
    accesoDatos fachada;
    public ManejoBD(){
        fachada= new accesoDatos();
    }
    
    public int crearFuncion(Funcion funcion)
    { 
        try {
            int acumDatos=1;
            String string_crearFuncion ="CREATE OR REPLACE Function "+funcion.getNombre()+"(";
            for (Dato dato:funcion.getDatos()){
                if(acumDatos<funcion.getDatos().size())
                {
                    string_crearFuncion+=dato.getNombre()+" IN "+dato.getTipo()+" , ";
                }else
                {
                    string_crearFuncion+=dato.getNombre()+" IN "+dato.getTipo();
                }
                acumDatos++;
            }
            String[ ]funcion_completa=funcion.getExpresion().split("return");
            string_crearFuncion+=")"
                    + "RETURN "+funcion.getType_return()
                    +" IS ";
                    
            for (Dato dato:funcion.getDatos()){
                    string_crearFuncion+=dato.getNombre()+"tmp"+" "+dato.getTipo()+" ; ";
            }
                    string_crearFuncion+=" BEGIN ";
                    
            Scanner scanner = new Scanner(funcion_completa[0]);
            while (scanner.hasNextLine()) {
                String line = scanner.nextLine();
                String[]operacion=line.split("=");
                String inicial=operacion[0]+"tmp";
                String igual=":=";
                String resto=operacion[1];
                string_crearFuncion+=inicial+igual+resto;
                // process the line
            }
            scanner.close();
                    /*String[]operacion=funcion_completa[0].split("=");
                    String inicial=operacion[0]+"tmp";
                    String igual=":=";
                    String resto=operacion[1];*/
                    
                    
                    string_crearFuncion+="RETURN ";
                     for (Dato dato:funcion.getDatos()){
                    funcion_completa[1]=funcion_completa[1].replace(dato.getNombre(), dato.getNombre()+"tmp");
                         
                    }
                     string_crearFuncion+=funcion_completa[1];
                    string_crearFuncion+=" \n" +
                    " EXCEPTION\n" +
                    "WHEN OTHERS THEN\n" +
                    "   raise_application_error(-20001,'An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);\n" +
                    "END;";
            
         //   System.out.println(string_crearFuncion);
            Connection conn= fachada.conectar();
            Statement stmt=conn.createStatement();
            stmt.executeUpdate(string_crearFuncion);
             String[]variable={funcion.getNombre(),funcion.getExpresion(),"","T_FUNC","0","0",""+funcion.getDatos().size(),funcion.getSintaxis()};
                ManejoBD b =new ManejoBD();
                b.insertarVariableBD(variable);
            return 1;
        } catch (SQLException ex) {
            ex.printStackTrace();
        }
        return 0;
    }
    public String runEval(String expression){
        /*select rpn_util.eval(
            rpn_util.parse('(3*A) * (2*B - 2*D)*3+F')
        ) as result
   from dual;*/
        LinkedList<String[]> total_result=new LinkedList();
        String query="select rpn_util2.eval(rpn_util2.compile('";
        query+=expression;
        query+="')) as result from dual";
        System.out.println(query);
                //+ "//ORDER BY aminos_vs_cyst DESC LIMIT "+top;
        try{
            Connection conn= fachada.conectar();
            Statement stmt=conn.createStatement();
            ResultSet rs=stmt.executeQuery(query);
            while(rs.next()){
                String[] result=new String[4];
                result[0]=rs.getString("result");
    //            JOptionPane.showMessageDialog(null,result[0]);
                return result[0];
            }
        }catch(Exception e){
        }     
        return "";
    }
    public LinkedList<String[]>getVariables(int top){
        LinkedList<String[]> total_result=new LinkedList();
       String query="SELECT * FROM jo_variables ORDER BY nombre";
       // System.out.println(query);
         
        try{
            Connection conn= fachada.conectar();
            Statement stmt=conn.createStatement();
            ResultSet rs=stmt.executeQuery(query);
            while(rs.next()){
                String[] result=new String[3];
                result[0]=rs.getString("nombre");
                result[1]=rs.getString("expression");
                result[2]=rs.getString("var_type");
                total_result.add(result);
            }
        }catch(Exception e){
        }
        return total_result;
    }
    public LinkedList<String[]>getVariablesByType(String tipo){
        if(tipo.equalsIgnoreCase("entero")){
            tipo="T_NUMBER";
        }
        LinkedList<String[]> total_result=new LinkedList();
       String query="";
       if(tipo.length()>2)
       {
          query="SELECT * FROM jo_variables  WHERE VAR_TYPE like '"
                        +tipo
                        +"'  ORDER BY nombre";
       
       }else
       {
              query="SELECT * FROM jo_variables ORDER BY nombre";
       
       
       }
     //  System.out.println(query);
         
        try{
            Connection conn= fachada.conectar();
            Statement stmt=conn.createStatement();
            ResultSet rs=stmt.executeQuery(query);
            while(rs.next()){
                System.out.println("entro");
                String[] result=new String[3];
                result[0]=rs.getString("nombre");
                       System.out.println(rs.getString("nombre"));

                
                result[1]=rs.getString("expression");
                result[2]=rs.getString("var_type");
                total_result.add(result);
            }
        }catch(Exception e){
        }
        return total_result;
    }
    
    public LinkedList<String>getVariablesgroupedByType()
    {
        LinkedList<String> total_result=new LinkedList();
       String query="SELECT count(*),var_type FROM jo_variables group by var_type";
       System.out.println(query);
         
        try{
            Connection conn= fachada.conectar();
            Statement stmt=conn.createStatement();
            ResultSet rs=stmt.executeQuery(query);
            while(rs.next()){
                String result=rs.getString("var_type");
                total_result.add(result);
            }
        }catch(Exception e){
        }
        return total_result;
    }
    
    public String insertarVariableBD(String[] variable){
        if(variable[3].equals("Entero"))
        {
            variable[3]="T_NUMBER";
        }
        
        String query="";
        if(variable.length>6)
        {
            query="INSERT INTO JO_VARIABLES VALUES('"
                                        +variable[0]+"','"
                                        +variable[1]+"','"
                                        +variable[2]+"','"
                                        +variable[3]+"',"
                                        +variable[4]+",'"
                                        +variable[5]+"','"
                                        +variable[6]+"','"
                                        +variable[7]
                    +"')";
        }else
        {
            query="INSERT INTO JO_VARIABLES VALUES('"
                                        +variable[0]+"','"
                                        +variable[1]+"','"
                                        +variable[2]+"','"
                                        +variable[3]+"',"
                                        +variable[4]+",'"
                                        +variable[5]+"','"
                                        +"0"+"','"
                                        +""
                    +"')";
        
        }
        System.out.println(query);
        try{
            Connection conn= fachada.conectar();
            Statement stmt=conn.createStatement();
             int numFilas = stmt.executeUpdate(query);
            JOptionPane.showMessageDialog(null,"se inserto la variable "+variable[1]+" con exito");
        }catch(Exception e){
        }
        return "";
    }
    public static void main(String args[]) {
        /*
        CREAR FUNCION DINAMICAMENTE
        LinkedList<Dato> datos;
        datos=new LinkedList<Dato>();
        Dato datox=new Dato();
        datox.setNombre("x");
        datox.setTipo("number");
        
        Dato datoy=new Dato();
        datoy.setNombre("y");
        datoy.setTipo("number");
        
        datos.add(datox);
        datos.add(datoy);
             
         ManejoBD b=new ManejoBD();
          Funcion funcion=new Funcion("test", " ", " ", " x=x+1;\n" +
            "y=y+1;\n" +
            "return  x+y;", "number", datos) ;
         b.crearFuncion(funcion);
   */
    /*
        INSERTAR FUNCIONES QUE VENIAN EN EL RPN2
           String[]variable={"ABS","","","T_FUNC","0","0","1",""};
        String[]variable1={"MIN","","","T_FUNC","0","0","2",""};
        String[]variable2={"MAX","","","T_FUNC","0","0","2",""};
        String[]variable3={"COS","","","T_FUNC","0","0","1",""};
        String[]variable4={"SIN","","","T_FUNC","0","0","1",""};
        String[]variable5={"TAN","","","T_FUNC","0","0","1",""};
        String[]variable6={"SQRT","","","T_FUNC","0","0","1",""};
        String[]variable7={"EXP","","","T_FUNC","0","0","1",""};
        String[]variable8={"LN","","","T_FUNC","0","0","1",""};
        String[]variable9={"LOG","","","T_FUNC","0","0","2",""};
        String[]variable10={"CEIL","","","T_FUNC","0","0","1",""};
        String[]variable11={"FLOOR","","","T_FUNC","0","0","1",""};
        String[]variable12={"FLOOR","","","T_FUNC","0","0","1",""};
        String[]variable13={"ROUND","","","T_FUNC","0","0","1",""};
        String[]variable14={"IF","","","T_FUNC","0","0","3",""};
        String[]variable15={"ISNULL","","","T_FUNC","0","0","1",""};
        String[]variable16={"NULLIF","","","T_FUNC","0","0","2",""};
        String[]variable17={"FYEARDAY","","","T_FUNC","0","0","0",""};
        String[]variable18={"FWEEKDAY","","","T_FUNC","0","0","0",""};
        String[]variable19={"FDAY","","","T_FUNC","0","0","0",""};
        String[]variable20={"FMONTH","","","T_FUNC","0","0","0",""};
        String[]variable21={"FYEAR","","","T_FUNC","0","0","0",""};
        String[]variable22={"FHOUR","","","T_FUNC","0","0","0",""};
        String[]variable23={"FHOURBETWEEN","","","T_FUNC","0","0","2",""};

        ManejoBD b =new ManejoBD();
        b.insertarVariableBD(variable);
        b.insertarVariableBD(variable1);
        b.insertarVariableBD(variable2);
        b.insertarVariableBD(variable3);
        b.insertarVariableBD(variable4);
        b.insertarVariableBD(variable5);
        b.insertarVariableBD(variable6);
        b.insertarVariableBD(variable7);
        b.insertarVariableBD(variable8);
        b.insertarVariableBD(variable9);
        b.insertarVariableBD(variable10);
        b.insertarVariableBD(variable11);
        b.insertarVariableBD(variable12);
        b.insertarVariableBD(variable13);
        b.insertarVariableBD(variable14);
        b.insertarVariableBD(variable15);
        b.insertarVariableBD(variable16);
        b.insertarVariableBD(variable17);
        b.insertarVariableBD(variable18);
        b.insertarVariableBD(variable19);
        b.insertarVariableBD(variable20);
        b.insertarVariableBD(variable21);
        b.insertarVariableBD(variable22);
        b.insertarVariableBD(variable23);
    */
 

   
    
    
    }

}//fin clase



