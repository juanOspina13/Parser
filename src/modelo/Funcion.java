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
    String nombre;
    String sintaxis;
    String ayuda;
    String expresion;
    String type_return;
    LinkedList <Dato> datos;

    public Funcion(String nombre, String sintaxis, String ayuda, String expresion, String type_return, LinkedList<Dato> datos) {
        this.nombre = nombre;
        System.out.println("nombre=>"+nombre);
        this.sintaxis = sintaxis;
        System.out.println("sintaxis=>"+sintaxis);
        
        this.ayuda = ayuda;
        System.out.println("ayuda=>"+ayuda);
        
        this.expresion = expresion;
        System.out.println("expresion=>"+expresion);
        
        this.type_return = type_return;
        System.out.println("type_return=>"+type_return);
        
        this.datos = datos;
        System.out.println("datos=>"+datos);
        
    }

    public String getNombre() {
        return nombre;
    }

    public String getSintaxis() {
        return sintaxis;
    }

    public String getAyuda() {
        return ayuda;
    }

    public String getExpresion() {
        return expresion;
    }

    public String getType_return() {
        return type_return;
    }

    public LinkedList<Dato> getDatos() {
        return datos;
    }

    



    
}
