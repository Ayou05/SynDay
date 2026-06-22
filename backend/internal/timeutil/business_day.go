package timeutil

import "time"

const DayBoundaryHour = 4

// BusinessDate returns the SynDay business date in the configured location.
// Times from 00:00 through 03:59:59 belong to the previous calendar date.
func BusinessDate(at time.Time, location *time.Location) time.Time {
	local := at.In(location)
	if local.Hour() < DayBoundaryHour {
		local = local.AddDate(0, 0, -1)
	}
	return time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, location)
}

func BusinessDateString(at time.Time, location *time.Location) string {
	return BusinessDate(at, location).Format("2006-01-02")
}

// NextBoundary returns the next 04:00 boundary after at.
func NextBoundary(at time.Time, location *time.Location) time.Time {
	local := at.In(location)
	boundary := time.Date(local.Year(), local.Month(), local.Day(), DayBoundaryHour, 0, 0, 0, location)
	if !local.Before(boundary) {
		boundary = boundary.AddDate(0, 0, 1)
	}
	return boundary
}

// AttributionDate preserves the start business date for sessions crossing
// midnight or the 04:00 business boundary.
func AttributionDate(startedAt time.Time, location *time.Location) time.Time {
	return BusinessDate(startedAt, location)
}
