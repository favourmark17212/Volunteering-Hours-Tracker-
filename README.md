# 🕐 Volunteering Hours Tracker

A blockchain-based time logging system built on Stacks that teaches volunteers how to track and verify their community service hours.

## 🌟 Features

- ✅ **Volunteer Registration** - Register with name and email
- 📝 **Activity Management** - Create volunteering activities and organizations  
- ⏱️ **Time Logging** - Log hours spent on specific activities
- ✔️ **Hour Verification** - Activity creators and admins can verify logged hours
- 📊 **Progress Tracking** - View total and verified hours per volunteer
- 🏆 **Activity Stats** - Track hours per activity and volunteer

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity smart contracts

### Installation

1. Clone this repository
2. Install dependencies:
   ```bash
   npm install
   ```
3. Run tests:
   ```bash
   clarinet test
   ```

## 📖 Usage Guide

### 🧑‍🤝‍🧑 Register as a Volunteer

```clarity
(contract-call? .volunteering-hours-tracker register-volunteer "John Doe" "john@example.com")
```

### 🎯 Create an Activity

```clarity
(contract-call? .volunteering-hours-tracker create-activity 
  "Beach Cleanup" 
  "Ocean Conservation Society" 
  "Monthly beach cleanup event")
```

### ⏰ Log Volunteering Hours

```clarity
(contract-call? .volunteering-hours-tracker log-hours 
  u1          ; activity-id
  u4          ; hours worked
  u20240101   ; date (YYYYMMDD format)
  "Cleaned north beach section")
```

### ✅ Verify Hours (Admin/Activity Creator)

```clarity
(contract-call? .volunteering-hours-tracker verify-hours u1) ; log-id
```

### 📊 Check Your Stats

```clarity
;; Get volunteer information
(contract-call? .volunteering-hours-tracker get-volunteer-info 'SP1234...)

;; Get total hours
(contract-call? .volunteering-hours-tracker get-volunteer-total-hours 'SP1234...)

;; Get verified hours
(contract-call? .volunteering-hours-tracker get-volunteer-verified-hours 'SP1234...)
```

## 🔧 Smart Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `register-volunteer` | Register a new volunteer | `name`, `email` |
| `create-activity` | Create a volunteering activity | `name`, `organization`, `description` |
| `log-hours` | Log time spent volunteering | `activity-id`, `hours`, `date`, `description` |
| `verify-hours` | Verify logged hours | `log-id` |
| `update-volunteer-info` | Update volunteer details | `name`, `email` |
| `deactivate-volunteer` | Deactivate a volunteer (admin only) | `volunteer` |
| `deactivate-activity` | Deactivate an activity | `activity-id` |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-volunteer-info` | Get volunteer details | Volunteer record |
| `get-activity-info` | Get activity details | Activity record |
| `get-time-log` | Get time log entry | Time log record |
| `get-volunteer-total-hours` | Get total logged hours | `uint` |
| `get-volunteer-verified-hours` | Get verified hours | `uint` |
| `is-volunteer-registered` | Check if volunteer exists | `bool` |
| `is-activity-active` | Check if activity is active | `bool` |

## 🏗️ Data Structure

### Volunteer Record
```clarity
{
  name: (string-ascii 50),
  email: (string-ascii 100), 
  total-hours: uint,
  verified-hours: uint,
  registration-block: uint,
  is-active: bool
}
```

### Activity Record
```clarity
{
  name: (string-ascii 100),
  organization: (string-ascii 100),
  description: (string-ascii 200),
  created-by: principal,
  is-active: bool,
  creation-block: uint
}
```

### Time Log Record
```clarity
{
  volunteer: principal,
  activity-id: uint,
  hours: uint,
  date: uint,
  description: (string-ascii 200),
  is-verified: bool,
  verified-by: (optional principal),
  log-block: uint
}
```

## 🔐 Security Features

- ✅ Only registered volunteers can log hours
- ✅ Only activity creators and contract owner can verify hours
- ✅ Input validation for all parameters
- ✅ Prevents duplicate volunteer registrations
- ✅ Activity and volunteer deactivation controls

## 🎓 Learning Objectives

This contract teaches developers:
- 📚 **Time-based data management** on blockchain
- 🗺️ **Multi-map data relationships** between volunteers, activities, and logs
- 🔒 **Access control patterns** for verification workflows
- 📈 **State aggregation** for tracking cumulative hours
- ✅ **Data validation** and error handling best practices

## 🚧 Future Enhancements

- 🏆 Leaderboard implementation
- 📈 Organization statistics dashboard
- 🏅 Achievement and badge system
- 📱 Mobile-friendly interface
- 🔔 Notification system for new activities

## 📜 License

This project is open source and available under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

*Built with ❤️ for the volunteer community*
