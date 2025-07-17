#################################################
#      GiD-Tcl procedures invoked by GiD        #
#################################################

proc InitGIDProject { dir } {
    FEMpy::SetDir $dir ;#store to use it later
    FEMpy::ModifyMenus
    gid_groups_conds::open_conditions menu
    
    if { [info procs ReadProblemtypeXml] != "" } {
        #this procedure exists after GiD 11.1.2b
        set data [ReadProblemtypeXml [file join $dir FEMpy.xml] Infoproblemtype {Version MinimumGiDVersion}]                
    } else {
        #FEMpy::ReadProblemtypeXml is a copy of ReadProblemtypeXml to be able to work with previous GiD's
        set data [FEMpy::ReadProblemtypeXml [file join $dir FEMpy.xml] Infoproblemtype {Version MinimumGiDVersion}]
    }
    if { $data == "" } {
        WarnWinText [= "Configuration file %s not found" [file join $dir FEMpy.xml]]
        return 1
    }
    array set problemtype_local $data
    set FEMpy::VersionNumber $problemtype_local(Version)
    
    FEMpy::Splash 1
}

proc ChangedLanguage { language } {
    FEMpy::ModifyMenus ;#to customize again the menu re-created for the new language
}

proc AfterWriteCalcFileGIDProject { filename errorflag } {   
    if { ![info exists gid_groups_conds::doc] } {
        WarnWin [= "Error: data not OK"]
        return
    }    
    set err [catch { FEMpy::WriteCalculationFile $filename } ret]
    if { $err } {       
        WarnWin [= "Error when preparing data for analysis (%s)" $::errorInfo]
        set ret -cancel-
    }
    return $ret
}

namespace eval FEMpy {
    variable current_xml_root
    set current_xml_root ""    
    set com_dict [dict create]
    variable problemtype_dir
    set edges(Triangle)           {{0 1} {1 2} {2 0}}
    set edges(Quadrilateral)      {{0 1} {1 2} {2 3} {3 0}}
    set edges(Tetrahedra)         {{0 1} {1 2} {2 0} {0 3} {1 3} {2 3}}
    set edges(Hexahedra)          {{0 1} {1 2} {2 3} {3 0} {4 5} {5 6} {6 7} {7 4} {0 4} {1 5} {2 6} {3 7}}
    set edges(HexahedraQuadratic) {{8}   {9}   {10}  {11}  {16}  {17}  {18}  {19}  {12}  {13}  {14}  {15}}
    set edges(Prism)              {{0 1} {1 2} {2 0} {3 4} {4 5} {5 3} {0 3} {1 4} {2 5}}
    set edges(Pyramid)            {{0 1} {1 2} {2 3} {3 0} {0 4} {1 4} {2 4} {3 4}}
}

#################################################
#      namespace implementing procedures        #
#################################################

proc FEMpy::SetDir { dir } {  
    variable problemtype_dir
    set problemtype_dir $dir
}

proc FEMpy::GetDir { } {  
    variable problemtype_dir
    return $problemtype_dir
}

proc FEMpy::Splash { {self_close 1} } {    
    variable problemtype_dir
    variable VersionNumber
    #set text "Version $VersionNumber"
    #GidUtils::Splash [file join $problemtype_dir images Web_png_COLOR.gif] .splash $self_close [list $text 6 116]   
}

proc FEMpy::About { } {
    set self_close 0
    #FEMpy::Splash $self_close
} 

proc FEMpy::ModifyMenus { } {   
    if { [GidUtils::IsTkDisabled] } {  
        return
    }          
    foreach menu_name {Conditions Interval "Interval Data" "Local axes"} {
        GidChangeDataLabel $menu_name ""
    }       
    GidAddUserDataOptions --- 1    
    GidAddUserDataOptions [= "FEMpy menu"] [list gid_groups_conds::open_conditions menu] 2
    GidAddUserDataOptions [= "Mesh Hexaedra"] [list FEMpy::NormalHexaedraMeshGeneration] 3
    GidAddUserDataOptions [= "Mesh Tetrahedra"] [list FEMpy::NormalTetrahedraMeshGeneration] 4
    GidAddUserDataOptions [= "Mesh Triangle"] [list FEMpy::NormalTriangleMeshGeneration] 5
    GiDMenu::UpdateMenus
}

######################################################################
# example procedures asking GiD_Info and doing things with GiD_Process
proc FEMpy::CreateWindow { } {  
    if { [GidUtils::AreWindowsDisabled] } {
        return
    }
    set w .gid.win_example
    InitWindow $w [= "PROBLEM TYPE FEMpy"] ExampleCMAS "" "" 1
    if { ![winfo exists $w] } return ;# windows disabled || usemorewindows == 0
    ttk::frame $w.top
    ttk::label $w.top.title_text -text [= "  Version 1.0 Fall 2018"]   
    ttk::frame $w.information -relief ridge   
    ttk::label $w.information.help   -text [= "   Bugs errores y demas -> fturon@cimne.upc.edu"] 
    ttk::frame $w.bottom
    ttk::button $w.bottom.start -text [= "Continue"] -command [list destroy $w]
    grid $w.top.title_text -sticky ew
    grid $w.top -sticky new   
    grid $w.information.help -sticky w -padx 6 -pady 6
    grid $w.information -sticky nsew    
    grid $w.bottom.start -padx 6
    grid $w.bottom -sticky sew -padx 6 -pady 6
    if { $::tcl_version >= 8.5 } { grid anchor $w.bottom center }
    grid rowconfigure $w 1 -weight 1
    grid columnconfigure $w 0 -weight 1    
}

proc FEMpy::NormalHexaedraMeshGeneration {} {
    GiD_Process Mescape Meshing ElemType Quadrilateral 1:all escape
    GiD_Process Mescape Meshing ElemType Hexaedra 1:all escape
    GiD_Process Mescape Meshing Structured Volumes Size 1:all escape
    GiD_Process 1:all escape escape
}

proc FEMpy::NormalTetrahedraMeshGeneration {} {
    GiD_Process Mescape Meshing ElemType Triangle 1:all escape
    GiD_Process Mescape Meshing ElemType Tetrahedra 1:all escape
}

proc FEMpy::NormalTriangleMeshGeneration {} {
    GiD_Process Mescape Meshing ElemType Triangle 1:all escape
    GiD_Process Mescape Meshing Structured Surfaces Size 1:all escape
    GiD_Process 1:all escape escape
}
###################################################################################################
########## Procedimeintos para imprimir informacion de las condiciones                   ##########
###################################################################################################

proc FEMpy::GetBlocksList { domNode args containerName } {    
    set x_path {//container[@n=$containerName]}
    set dom_materials [$domNode selectNodes $x_path]
    if { $dom_materials == "" } {
        error [= "xpath '%s' not found in the spd file" $x_path]
    }
    set image $containerName
    set result [list]
    foreach dom_material [$dom_materials selectNodes blockdata] {
        set name [$dom_material @name] 
        lappend result [list 0 $name $name $image 1]
    }
    return [join $result ,]
}

proc FEMpy::GetModelType { domNode args model } {
    set modelType [ FEMpy::GetNodeValue {/FEMpy_customlib_data/value[@n='dimension']} ]
    if { $modelType == "2D" } {
        return Truss,Beam,Shell,PlaneStress,PlaneStrain
    } elseif { $modelType == "3D" } {
        return Shell,Solid
    }
}

proc FEMpy::GetGroupType { domNode args model } {
    set modelType [ FEMpy::GetNodeValue {/FEMpy_customlib_data/value[@n='model']} ]
    if       { $modelType == "Truss" } {
        return line
    } elseif { $modelType == "Beam" } {
        return line
    } elseif { $modelType == "Shell" } {
        return surface
    } elseif { $modelType == "PlaneStress" } {
        return surface
    } elseif { $modelType == "PlaneStrain" } {
        return surface
    } elseif { $modelType == "Solid" } {
        return volume
    }
}

###################################################################################################
########## Procedimeintos para imprimir informacion de las bases de datos XML            ##########
###################################################################################################

proc FEMpy::WriteNodeValue { xpath } {
    set document [$::gid_groups_conds::doc documentElement]
    set xml_node [$document selectNodes $xpath]
    if {  [llength $xml_node] == 1 } {
        set value [get_domnode_attribute $xml_node v]
        FEMpy::WriteString $value
    }
}

proc FEMpy::GetNodeValue { xpath } {
    set document [$::gid_groups_conds::doc documentElement]
    set xml_node [$document selectNodes $xpath]
    if {  [llength $xml_node] == 1 } {
        set value [get_domnode_attribute $xml_node v]
    }
    return $value
}

proc FEMpy::WriteValuesInsideContainer { xpath } {
    set document [$::gid_groups_conds::doc documentElement]
    set container [$document selectNodes $xpath]
    set VALUES [dict create]
    foreach valueInside [$container selectNodes value] {
        set value [get_domnode_attribute $valueInside v]
        dict set VALUES [$valueInside @n] $value
    }
    GiD_WriteCalculationFile puts $VALUES
}

proc FEMpy::WriteDatabaseSimple { xpath } {
    set document [$::gid_groups_conds::doc documentElement]
    set blocks [$document selectNodes $xpath]
    if {$blocks eq ""} {error [= "No blocks found"]}
    foreach block $blocks {
        set block_name [$block @name]
        regsub -all { } $block_name "" block_name
        GiD_WriteCalculationFile puts $block_name
        set dict_nodes [dict create]
        foreach node [$block selectNodes value] {
            set value [get_domnode_attribute $node v]
            regsub -all { } $value "" value
            dict set dict_nodes [$node @n] $value
        }
        dict set dict_blocks $block_name $dict_nodes
        GiD_WriteCalculationFile puts $dict_nodes
    }
}

proc FEMpy::WriteDatabaseInDatabase { xpath } {
    set document [$::gid_groups_conds::doc documentElement]
    set stages [$document selectNodes $xpath]
    if {$stages eq ""} {error [= "No materials block found"]}
    foreach stagesnode $stages {
        set stages_name [$stagesnode @name]
        GiD_WriteCalculationFile puts "@@@@@@@@@@@@@@@@@@@@ flagNewCompositeP"
        regsub -all { } $stages_name "" stages_name
        #Imprimeix el nom del Laminat sense espais
        GiD_WriteCalculationFile puts $stages_name
        set props_dict [dict create]
        #set blocks [$document selectNodes $xpath]
        foreach block [$stagesnode selectNodes blockdata] {
            set block_name [$block @name]
            regsub -all { } $block_name "" block_name
            GiD_WriteCalculationFile puts $block_name
            set dict_nodes [dict create]
            foreach node [$block selectNodes value] {
                set value [get_domnode_attribute $node v]
                regsub -all { } $value "" value
                dict set dict_nodes [$node @n] $value
            }
            dict set dict_blocks $block_name $dict_nodes
            GiD_WriteCalculationFile puts $dict_nodes
        }
        
    }
}

###################################################################################################
########## Procedimeintos para imprimir informacion de las condiciones                   ##########
###################################################################################################
proc FEMpy::GetNumberConectivities { element_type } {
        set wordElement ""
        set n 0
        set quadratic [GiD_Info Project Quadratic]
        if { $element_type == "Hexahedra" } {
                if { $quadratic == 0 } {
                        set n 8
                        set wordElement "SH_8N_8G"
                } elseif { $quadratic == 1 } {
                        set n 20
                        set wordElement "SH_20N_27G"
                } elseif { $quadratic == 2 } {
                WarnWin [= "Error: Quadratic9 element type is not defined"]
                return
                }
        } elseif { $element_type == "Tetrahedra" } {
                if { $quadratic == 0 } {
                        set n 4
                        set wordElement "Tet4"
                } else {
                        set n 10
                        set wordElement "Tet10"
                }
        } elseif { $element_type == "Quadrilateral" } {
                if { $quadratic == 0 } {
                        set n 4
                        set wordElement "PSQ_4N_4G"
                } else {
                        set n 8
                        set wordElement "PSQ_8N_9G"
                }
        } elseif { $element_type == "Triangle" } {
                if { $quadratic == 0 } {
                        set n 3
                        set wordElement "Tri3"
                } else {
                        set n 6
                        set wordElement "Tri6"
                }
        }
    return [list $n $wordElement]
}

proc FEMpy::GetMaterialDicc {} {
    set counter 0        
        
    set xpath {/FEMpy_customlib_data/container[@n='laminates']/blockdata[@n='laminate']}
    
    set document [$::gid_groups_conds::doc documentElement]
    set materials [$document selectNodes $xpath]
    
    foreach material $materials {
        set name [$material @name]
        set counter [expr {$counter + 1}]
        dict set materialDicc $name $counter
    }
    return $materialDicc
}

proc FEMpy::GetFormatPrintConectivities { element_type dimension printedCoordsFlag} {
    set format [FEMpy::GetNumberConectivities $element_type]
    set element_num_nodes [lindex $format 0]
    set elementType [lindex $format 1]
    set sub_format_connectivities [lrepeat $element_num_nodes %d]

    set document [$::gid_groups_conds::doc documentElement]
    set condition_formatsSurfaces_PF ""
    
    set materialDicc [FEMpy::GetMaterialDicc]
    
    set num [GiD_Info Mesh NumElements $element_type]
    
    if {[GiD_Info Mesh NumElements $element_type] != 0} {
        FEMpy::WriteString "MESH \"$elementType\" dimension $dimension ElemType $element_type Nnode $element_num_nodes"
                        
        if {$printedCoordsFlag == 0} {
            FEMpy::WriteCoordinatesFile $dimension
            set printedCoordsFlag 1
        }
                    
                FEMpy::WriteString "Elements"
                        
                if {$dimension == "3"} {
                        foreach gNode [$document selectNodes {//condition[@n="zonesMEC3D"]/group}] {
                            set n [$gNode @n]
                            set value_node [$gNode selectNodes {./value}]
                            set name_value [$value_node @v]
                        
                            set value [dict get $materialDicc $name_value]
                        
                            regsub -all { } $name_value "" name_value
                            dict set format $n "%d $sub_format_connectivities $value \n"
                        }
                } elseif {$dimension == "2"} {
                        foreach gNode [$document selectNodes {//condition[@n="zonesSHELL"]/group}] {
                            set n [$gNode @n]
                            set value_node [$gNode selectNodes {./value}]
                            set name_value [$value_node @v]
                        
                            set value [dict get $materialDicc $name_value]
                        
                            regsub -all { } $name_value "" name_value
                            dict set format $n "%d $sub_format_connectivities $value \n"
                        }
                }
                        
                GiD_WriteCalculationFile connectivities -elemtype $element_type -elements_faces all -sorted $format 
                FEMpy::WriteString "End Elements"
    }
        
        return $printedCoordsFlag
        
}

proc FEMpy::GetElementNumEdges { element_type } {
    variable edges
    return [llength $edges($element_type)]
}

proc FEMpy::GetEdgeNodes { element_type element_nodes i_edge } {
    variable edges
    lassign [lindex $edges($element_type) $i_edge] i0 i1
    return [list [lindex $element_nodes $i0] [lindex $element_nodes $i1]]
}


###################################################################################################
########## Procedimientos sagrados. NO TOCAR!!!                                          ##########
###################################################################################################

proc FEMpy::InitWriteFile {filename} {
    GiD_WriteCalculationFile init $filename ;#initialize writting
    set root [$::gid_groups_conds::doc documentElement] ;#xml document to get some tree data
    FEMpy::SetBaseRoot $root
}

proc FEMpy::EndWriteFile { } {
    GiD_WriteCalculationFile end
}

proc FEMpy::WriteString { str } {
    GiD_WriteCalculationFile puts $str
}

proc FEMpy::SetBaseRoot {root} {
    variable current_xml_root
    set current_xml_root $root
}

proc FEMpy::CopyName { xpath } {
    set document [$::gid_groups_conds::doc documentElement]
    set xml_node [$document selectNodes $xpath]
    foreach blockmaterial $xml_node {
        set value [get_domnode_attribute $blockmaterial name]
        foreach nameNode [$blockmaterial selectNodes value] {
            $nameNode setAttribute v $value
        }
    }
}

proc FEMpy::WriteCoordinates {formats {flags ""}} {
    # Geometry factor (here the geometry unit declared by the user is converted to 'm')  
    set mesh_unit [gid_groups_conds::give_mesh_unit]
    set mesh_factor [lindex [gid_groups_conds::give_unit_factor L $mesh_unit] 0]
    # efficient CustomLib specialized procedure to print everything related with nodes or elements
    if {$flags eq ""} {
        set result [GiD_WriteCalculationFile coordinates -factor $mesh_factor $formats]
    } else {
        set result [GiD_WriteCalculationFile coordinates $flags -factor $mesh_factor $formats]
    } 
    return $result
}

proc FEMpy::WriteCoordinatesFile {dimension} {
    FEMpy::WriteString "Coordinates"
    if {$dimension eq "3"} {
            FEMpy::WriteCoordinates "%8d %14.5e %14.5e %14.5e\n"
    } else {
            FEMpy::WriteCoordinates "%8d %14.5e %14.5e\n"
    }
    FEMpy::WriteString "End Coordinates"
    FEMpy::WriteString ""
}

###################################################################################################
########## Aqui se define la impresion usando los procedimientos antes definidos         ##########
###################################################################################################
#print data in the .dat calculation file (instead of a classic .bas template)
proc FEMpy::WriteCalculationFile { filename } {
    
    FEMpy::InitWriteFile $filename
    
    FEMpy::EndWriteFile ;
    
}

proc FEMpy::InitWriteFile {filename} { 
    
    set len [string length $filename]
    
    set counter 0
    while {[string index $filename [expr $len - $counter]]!="/"} {
        incr counter 1
    }
    
    set directoryName [ string range $filename 0 [expr $len - $counter ] ]
    set problemName [ string range $filename [expr $len - $counter + 1 ] [expr $len - 5] ] 
    
    file mkdir "${directoryName}data"
    
    set root [$::gid_groups_conds::doc documentElement] ;#xml document to get some tree data
    FEMpy::SetBaseRoot $root
    
    set filenameSets "${directoryName}data/${problemName}.set"
    GiD_WriteCalculationFile init $filenameSets
    FEMpy::WriteSets $filenameSets
    GiD_WriteCalculationFile end
    
    set filenameBC "${directoryName}data/${problemName}.bcs"
    GiD_WriteCalculationFile init $filenameBC
    FEMpy::WriteBCs $filenameBC
    GiD_WriteCalculationFile end
    
    set filenameLD "${directoryName}data/${problemName}.lds"
    GiD_WriteCalculationFile init $filenameLD
    FEMpy::WriteLDs $filenameLD
    GiD_WriteCalculationFile end
    
    set filenameMesh "${directoryName}data/${problemName}.msh"
    GiD_Process Mescape Files WriteMesh $filenameMesh
        
}

proc FEMpy::EndWriteFile { } {
    GiD_WriteCalculationFile end
}

proc FEMpy::WriteString { str } {
    GiD_WriteCalculationFile puts $str
}

proc FEMpy::SetBaseRoot {root} {
    variable current_xml_root
    set current_xml_root $root
}

proc FEMpy::WriteSets { filename } {
    
    set address "zones"
    set blockName "material"
    
    set document [$::gid_groups_conds::doc documentElement]
    
    FEMpy::WriteString "set_definition"
    
    set ID 1
    foreach gNode [$document selectNodes {//condition[@n=$address]/group}] {
        set condition_formats ""
        set n [$gNode @n]
        dict set condition_formats $n "%d $ID \n"
        GiD_WriteCalculationFile elements $condition_formats
        incr ID 1
    }
    
    FEMpy::WriteString "set_end"
    
}

proc FEMpy::WriteBCs { filename } {
    
    set document [$::gid_groups_conds::doc documentElement]
    

    set address "dirichlet"
    
    FEMpy::WriteString "on_nodes"

    FEMpy::PrintCondition $document $address
    
    FEMpy::WriteString "end_on_nodes"

    
    set address "newman"
    
    FEMpy::WriteString "on_boundary"

    FEMpy::PrintCondition $document $address
    
    FEMpy::WriteString "end_on_boundary"
    
}

proc FEMpy::WriteLDs { filename } {
    
    set document [$::gid_groups_conds::doc documentElement]
    

    set address "nodal"
    
    FEMpy::WriteString "on_node"

    FEMpy::PrintCondition $document $address
    
    FEMpy::WriteString "end_on_node"
    

    set address "distribuited"
    
    FEMpy::WriteString "on_boundary"

    FEMpy::PrintCondition $document $address
    
    FEMpy::WriteString "end_on_boundary"
    
}

proc FEMpy::PrintCondition { document address } {

    foreach gNode [$document selectNodes {//condition[@n=$address]/group}] {
        set condition_formats ""
        set n [$gNode @n]
        
        set flags_node [$gNode selectNodes {./value[@n="flags"]}]
        set flags [$flags_node @v]
        
        set values_node [$gNode selectNodes {./value[@n="values"]}]
        set values [$values_node @v]
        
        dict set condition_formats $n "%d $flags $values \n"
        
        GiD_WriteCalculationFile nodes $condition_formats
    }

}

proc GiD_Event_AfterRunCalculation { basename dir problemtypedir where error errorfilename } {
    
    set modelType [ FEMpy::GetNodeValue {/FEMpy_customlib_data/value[@n='model']} ]
    
    if {$modelType eq "2D"} {
    
        set filenameMesh "${dir}/data/${basename}.msh"
    
        set data [GidUtils::ReadFile $filenameMesh]

        set data [string map {{dimension 3} {dimension 2}} $data]
    
        GidUtils::WriteFile $filenameMesh $data
    
    }

}
