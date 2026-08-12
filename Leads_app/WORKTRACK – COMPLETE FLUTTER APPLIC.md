WORKTRACK – COMPLETE FLUTTER APPLICATION

You are a senior Flutter architect, Firebase architect, UI/UX designer, product manager, and full-stack engineer.

Build a complete production-ready Flutter application called WorkTrack.

The application is a Workforce Management, Attendance Tracking, Lead Management, Follow-Up Management, and Order Tracking platform for field service companies.

The generated project must be enterprise-grade, scalable, modular, cleanly structured, and ready for deployment.

TECH STACK

Frontend:

Flutter (Latest Stable Version)
Material 3
Responsive Design
Riverpod State Management
Go Router
Flutter Hooks

Backend:

Firebase Authentication
Cloud Firestore
Firebase Storage
Firebase Cloud Messaging
Firebase Analytics
Crashlytics

Architecture:

Clean Architecture
Feature Based Folder Structure
Repository Pattern
Service Layer
Dependency Injection
APP NAME

WorkTrack

Tagline:

Manage Employees, Leads, Orders and Attendance in One Platform

PRIMARY COLORS

Primary:
#4F46E5

Secondary:
#6366F1

Success:
#22C55E

Warning:
#F59E0B

Danger:
#EF4444

Background:
#F8FAFC

Cards:
#FFFFFF

Text:
#111827

TARGET USERS
Super Admin
Company Admin
Employee
ROLE BASED ACCESS

SUPER ADMIN

Can:

Manage companies
Manage subscriptions
Manage plans
View all company data
Suspend companies
Enable companies
View platform analytics

COMPANY ADMIN

Can:

Add employees
View attendance
Manage leads
Manage orders
View reports
Assign tasks

EMPLOYEE

Can:

Check In
Check Out
Add leads
Update follow-ups
Update orders
Upload documents
AUTHENTICATION

Create:

Login Screen
Register Screen
Forgot Password Screen

Methods:

Email Login
Mobile Login
Password Login

Future Ready:

OTP Login
Google Login
SPLASH SCREEN

Show:

WorkTrack Logo

Animated Logo

Check Login Session

Navigate Automatically

DASHBOARD

Create dashboard similar to provided references.

Top Section:

Greeting

Good Morning User

Profile Image

Notification Icon

Company Name

Attendance Card

Show:

Check In Button

Check Out Button

Current Status

Location Status

DASHBOARD STATS

Show:

Present Employees

Leads Added

Follow Ups

Orders

Revenue

Open Orders

Closed Orders

Attendance Percentage

QUICK ACTIONS

Grid Layout

Items:

Add Lead

Leads

Orders

Attendance

Follow Ups

Expenses

Tasks

Reports

Documents

Customers

Employees

Companies

ATTENDANCE MODULE

FEATURES

GPS Check In

GPS Check Out

Attendance History

Monthly Attendance

Daily Attendance

Attendance Reports

Attendance Calendar

Attendance Status

Late Arrival

Early Checkout

Work Duration Calculation

Future Ready:

Selfie Verification

Face Verification

Geofence

ATTENDANCE COLLECTION

attendance

Fields

attendanceId

companyId

employeeId

employeeName

checkInTime

checkOutTime

latitude

longitude

address

workHours

status

createdAt

LEAD MANAGEMENT MODULE

Create Lead Screen

Lead Listing Screen

Lead Details Screen

Edit Lead Screen

Delete Lead

LEAD FIELDS

leadId

companyId

customerName

mobileNumber

companyName

email

location

requirement

remarks

leadSource

assignedTo

status

createdAt

updatedAt

LEAD STATUS

New

Follow Up

Quotation Sent

Won

Lost

LEAD FEATURES

Search

Filter

Sort

Assign Employee

Add Notes

Add Documents

Lead Timeline

Lead Activities

Lead Conversion

Lead Analytics

FOLLOW UP MODULE

Create Follow Up

Edit Follow Up

Delete Follow Up

Reminder Notifications

Push Notifications

Follow Up Calendar

Upcoming Follow Ups

Missed Follow Ups

Completed Follow Ups

FOLLOW UP COLLECTION

followUps

Fields

followUpId

leadId

companyId

assignedUser

followUpDate

remarks

status

createdAt

ORDER MANAGEMENT MODULE

Won Leads can be converted into Orders

Create Order

Edit Order

Delete Order

Order Tracking

Order Timeline

Order Documents

Order Expenses

ORDER STATUS

Confirmed

Material Ordered

Installation

Completed

Closed

Cancelled

ORDER COLLECTION

orders

Fields

orderId

leadId

companyId

customerName

projectName

amount

status

expectedCompletion

assignedEngineer

createdAt

updatedAt

REPORTS MODULE

Generate:

Attendance Report

Lead Report

Lead Conversion Report

Order Report

Revenue Report

Employee Performance Report

Monthly Summary

Yearly Summary

Export:

PDF

Excel

CSV

DOCUMENT MODULE

Upload:

Images

PDF

Invoices

Quotations

Project Files

Store:

Firebase Storage

TASK MANAGEMENT

Create Task

Assign Task

Task Status

Task Comments

Task Attachments

Task Notifications

Task Calendar

EXPENSE MANAGEMENT

Add Expense

Expense Category

Expense Image Upload

Expense Approval

Expense Reports

CUSTOMER MODULE

Customer Listing

Customer Details

Customer Orders

Customer Leads

Customer Documents

COMPANY MODULE

Company Profile

Company Users

Subscription Details

Billing History

NOTIFICATION SYSTEM

Firebase Cloud Messaging

Notifications:

Attendance Reminder

Follow Up Reminder

Task Reminder

Order Update

Lead Assignment

Approval Notification

MULTI TENANT ARCHITECTURE

Every Collection Must Contain:

companyId

Data must be isolated between companies.

A company should never access another company's data.

Implement Firestore security rules.

FIRESTORE COLLECTION STRUCTURE

companies

users

attendance

leads

leadUpdates

followUps

orders

tasks

expenses

notifications

subscriptions

documents

reports

UI REQUIREMENTS

Use the uploaded reference images as inspiration.

Requirements:

Modern SaaS Design

Rounded Cards

Floating Action Button

Bottom Navigation

Material 3

Smooth Animations

Skeleton Loading

Shimmer Loading

Pull To Refresh

Dark Mode

Light Mode

Responsive Layout

Professional Typography

Empty States

Error States

Success States

NAVIGATION

Bottom Navigation Tabs

Home

Leads

Center FAB

Orders

More

MORE SCREEN

Profile

Employees

Customers

Companies

Reports

Analytics

Subscription

Settings

Support

About

Logout

ANALYTICS DASHBOARD

Charts

Revenue Trends

Lead Conversion

Employee Performance

Attendance Summary

Monthly Growth

SECURITY

Role Based Access

Firestore Security Rules

Input Validation

Secure Storage

Encrypted Sensitive Data

PROJECT STRUCTURE

lib/

core/

features/

authentication/

dashboard/

attendance/

leads/

followups/

orders/

tasks/

expenses/

customers/

companies/

reports/

notifications/

profile/

shared/

routes/

theme/

widgets/

services/

repositories/

models/

providers/

OUTPUT REQUIRED

Generate:

Complete Flutter Project
Firebase Integration
Firestore Collections
Data Models
Repositories
Services
Riverpod Providers
Screens
Widgets
Navigation
Firebase Security Rules
Dark Theme
Light Theme
Dummy Data
Setup Instructions
Android Build Support
iOS Build Support

Build this as a production-ready application, not a prototype.