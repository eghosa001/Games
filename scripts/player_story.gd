extends Node

const EmployeeSystemClass = preload("res://scripts/employee_system.gd")
const CorporateHistoryClass = preload("res://scripts/corporate_history.gd")
const RenewDailyClass = preload("res://scripts/renew_daily.gd")

var employees = EmployeeSystemClass.new()
var history = CorporateHistoryClass.new()
var daily = RenewDailyClass.new()

var initialized := false
var milestone_flags: Dictionary = {}

func initialize(day: int = 1) -> void:
    if initialized:
        return
    initialized = true
    if history.entries.is_empty():
        history.record_milestone(day, "Company founded", "RENEW began with a plan to restore abandoned property.")
        history.record_milestone(day, "First employees", "James Carter, Amara Okafor and Daniel Mensah joined the founding team.")

func record_milestone_once(day: int, key: String, title: String, detail: String) -> void:
    if milestone_flags.has(key) or history.has_title(title):
        return
    milestone_flags[key] = true
    history.record_milestone(day, title, detail)

func end_day(day: int, profit: int) -> Array[Dictionary]:
    initialize(day)
    var stories := employees.advance_day(profit)
    if profit > 0:
        record_milestone_once(day, "first_profit", "First profitable day", "The company proved it can turn restored capital into operating profit.")
    return stories

func hire_employee(name: String, role: String, skill: int = 50, salary: int = 180) -> Dictionary:
    return employees.hire(name, role, skill, salary)

func daily_news(day: int, state: Dictionary) -> Array[Dictionary]:
    initialize(day)
    return daily.generate(day, state)

func serialize() -> Dictionary:
    return {
        "employees": employees.serialize(),
        "history": history.serialize(),
        "milestone_flags": milestone_flags.duplicate(true),
        "initialized": initialized
    }

func deserialize(data: Dictionary) -> void:
    employees.deserialize(data.get("employees", {}))
    history.deserialize(data.get("history", {}))
    milestone_flags = data.get("milestone_flags", {}).duplicate(true)
    initialized = bool(data.get("initialized", true))
