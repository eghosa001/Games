extends Node

var owned := false
var restoration := 0
var stages = [["Neglected",0,0],["Cleaned",20,1500],["Repaired",40,3000],["Rebuilt",60,4500],["Installed",80,6000],["Designed",100,7500]]
var message := ""
var log_lines: Array[String] = []

func _log(text: String) -> void:
    log_lines.append(text)
