extends Node

var owned := false
var restoration := 0
var reputation := 0
var cash := 0
var rivals = load("res://scripts/competitors.gd").new()
var stages = [["Neglected",0,0],["Cleaned",20,1500],["Repaired",40,3000],["Rebuilt",60,4500],["Installed",80,6000],["Designed",100,7500]]
var message := ""
var log_lines: Array[String] = []

func _ready() -> void:
    rivals._normalize()

func _log(text: String) -> void:
    log_lines.append(text)
