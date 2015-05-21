/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

package modelo;

import java.util.LinkedList;

/**
 *
 * @author juan
 */
public class Funcion {
    String sbNombre;
    String sbSintaxis;
    String sbAyuda;
    String sbExpresion;
    String sbType_return;
    LinkedList <Dato> datos;

    public Funcion(String isbNombre, String isbSintaxis, String isbAyuda, String isbExpresion, String isbType_return, LinkedList<Dato> datos) {
        this.sbNombre = isbNombre;
        System.out.println("nombre=>"+sbNombre);
        
        this.sbSintaxis = isbSintaxis;
        System.out.println("sintaxis=>"+sbSintaxis);
        
        this.sbAyuda = isbAyuda;
        System.out.println("ayuda=>"+sbAyuda);
        
        this.expresion = isbExpresion;
        System.out.println("expresion=>"+sbExpresion);
        
        this.sbType_return = isbType_return;
        System.out.println("type_return=>"+sbType_return);
        
        this.datos = datos;
        System.out.println("datos=>"+datos);
        
    }

    public String getNombre() {
        return sbNombre;
    }

    public String getSintaxis() {
        return sbSintaxis;
    }

    public String getAyuda() {
        return sbAyuda;
    }

    public String getExpresion() {
        return sbExpresion;
    }

    public String getType_return() {
        return sbType_return;
    }

    public LinkedList<Dato> getDatos() {
        return datos;
    }

    



    
}
