package main

import (
	"encoding/csv"
	"fmt"
	"os"
	"sort"
	"strconv"
	"time"
)

func main() {
	// Path to your CSV file
	csvFile := "balances.csv"

	// Open the CSV file
	file, err := os.Open(csvFile)
	if err != nil {
		fmt.Printf("Error opening file: %v\n", err)
		return
	}
	defer file.Close()

	// Read the CSV file
	reader := csv.NewReader(file)
	records, err := reader.ReadAll()
	if err != nil {
		fmt.Printf("Error reading CSV file: %v\n", err)
		return
	}

	if len(records) < 2 {
		fmt.Println("Not enough records in CSV file")
		return
	}

	// Skip header row
	records = records[1:]

	// Extract starting balance from first row
	startingBalance, err := strconv.ParseFloat(records[0][2], 64)
	if err != nil {
		fmt.Printf("Error parsing starting balance: %v\n", err)
		return
	}
	fmt.Printf("Starting Balance: %.2f\n", startingBalance)

	// Parse the transactions (excluding the first row which is the starting balance)
	type Transaction struct {
		Name   string
		Date   time.Time
		Amount float64
	}

	var transactions []Transaction
	for i, record := range records {
		if i == 0 { // Skip the starting balance row
			continue
		}

		if len(record) < 3 {
			fmt.Println("Invalid record format")
			continue
		}

		transactionName := record[0]
		date, err := time.Parse("2 January, 2006", record[1])
		if err != nil {
			fmt.Printf("Error parsing date: %v\n", err)
			continue
		}

		amount, err := strconv.ParseFloat(record[2], 64)
		if err != nil {
			fmt.Printf("Error parsing amount: %v\n", err)
			continue
		}

		transactions = append(transactions, Transaction{
			Name:   transactionName,
			Date:   date,
			Amount: amount,
		})

		fmt.Printf("Transaction: %s on %s for $%.2f\n", transactionName, date.Format("2006-01-02"), amount)
	}

	// Sort transactions by date
	sort.Slice(transactions, func(i, j int) bool {
		return transactions[i].Date.Before(transactions[j].Date)
	})

	// Calculate the daily balance for each day in the billing cycle
	currentDate := time.Date(2025, time.April, 1, 0, 0, 0, 0, time.Local) // April 1, 2025
	endDate := time.Date(2025, time.April, 30, 0, 0, 0, 0, time.Local)    // April 30, 2025

	dailyBalances := make(map[time.Time]float64)
	currentBalance := startingBalance
	transactionIndex := 0

	for !currentDate.After(endDate) {
		// Apply any transactions that occurred on this day
		for transactionIndex < len(transactions) && transactions[transactionIndex].Date.Day() == currentDate.Day() {
			currentBalance += transactions[transactionIndex].Amount
			transactionIndex++
		}

		// Record the balance for this day
		dailyBalances[currentDate] = currentBalance

		// Move to the next day
		currentDate = currentDate.AddDate(0, 0, 1)
	}

	// Calculate the average daily balance
	var totalBalance float64
	totalDays := len(dailyBalances)

	// Print daily balances and sum them
	fmt.Println("\nDaily Balances:")
	var keys []time.Time
	for day := range dailyBalances {
		keys = append(keys, day)
	}
	sort.Slice(keys, func(i, j int) bool {
		return keys[i].Before(keys[j])
	})

	for _, day := range keys {
		balance := dailyBalances[day]
		fmt.Printf("%s: $%.2f\n", day.Format("2006-01-02"), balance)
		totalBalance += balance
	}

	averageDailyBalance := totalBalance / float64(totalDays)
	fmt.Printf("\nAverage Daily Balance: $%.2f\n", averageDailyBalance)
}
