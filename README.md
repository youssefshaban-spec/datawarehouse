# 🏢 Superstore Data Warehouse

## 📌 Overview
This project focuses on building a **Data Warehouse solution using SQL Server** to transform raw Superstore sales data into a structured analytical database ready for reporting and business analysis.

The project follows an **ETL workflow** with a layered architecture to clean, transform, and organize data efficiently.

---

## 🏗️ Data Warehouse Architecture

The Data Warehouse is designed using the following layers:

- 🟦 **Staging Layer:** Loading raw data from source files.
- 🟫 **Bronze Layer:** Storing raw extracted data.
- ⚪ **Silver Layer:** Cleaning and transforming data.
- 🟨 **Gold Layer:** Creating analytical tables using a Star Schema model.

---

## ⭐ Data Model

The final warehouse follows a **Star Schema** design:

### 📊 Dimension Tables
- 📅 Dim_Date
- 👤 Dim_Customer
- 📦 Dim_Product
- 🌍 Dim_Location
- 🚚 Dim_Ship_Mode

### 📈 Fact Table
- 🧾 Fact_Sales

---

## 🛠️ Technologies Used

- 🗄️ SQL Server
- 🖥️ SQL Server Management Studio (SSMS)
- 🔤 T-SQL
- 🔄 ETL Processes
- 🏗️ Data Modeling
- ⭐ Star Schema Design

---

## 🔄 Project Workflow

1. 📥 Extract raw Superstore data from source files.
2. 🗂️ Load data into the staging layer.
3. 🧹 Clean and transform data using SQL.
4. 🏗️ Build dimension and fact tables.
5. 📊 Create a structured warehouse optimized for analysis.

---

## ✨ Key Features

- 🧹 Data cleaning and transformation using SQL.
- ⭐ Dimensional modeling using Star Schema.
- 🔄 Creation of reusable ETL scripts.
- 📅 Date dimension generation.
- 📊 Preparation of analytical data for BI dashboards.

---

## 💡 Business Insights Supported

The warehouse enables analysis of:

- 💰 Sales and profit performance.
- 👥 Customer behavior.
- 📦 Product performance.
- 🌎 Regional analysis.
- 🚚 Shipping analysis.

---

## 📂 Project Structure
