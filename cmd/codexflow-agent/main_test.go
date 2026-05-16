package main

import (
	"testing"

	"codexflow/internal/config"
)

func TestCollectAccessURLsForLANListenAddr(t *testing.T) {
	previous := listLANIPv4s
	listLANIPv4s = func() []string {
		return []string{"192.168.1.20", "10.0.0.5"}
	}
	t.Cleanup(func() {
		listLANIPv4s = previous
	})

	access := collectAccessURLs(config.Config{
		ListenAddr: "0.0.0.0:4318",
		WebRoot:    "web",
	})

	if access.BrowserURL != "http://127.0.0.1:4318" {
		t.Fatalf("unexpected browser URL: %s", access.BrowserURL)
	}
	if access.PhoneURL != "http://192.168.1.20:4318" {
		t.Fatalf("unexpected phone URL: %s", access.PhoneURL)
	}
	if len(access.ExtraLANURLs) != 1 || access.ExtraLANURLs[0] != "http://10.0.0.5:4318" {
		t.Fatalf("unexpected extra LAN URLs: %#v", access.ExtraLANURLs)
	}
	if access.HealthzURL != "http://127.0.0.1:4318/healthz" {
		t.Fatalf("unexpected healthz URL: %s", access.HealthzURL)
	}
	if access.PhoneHint != "" {
		t.Fatalf("unexpected phone hint: %s", access.PhoneHint)
	}
}

func TestCollectAccessURLsForLoopbackListenAddr(t *testing.T) {
	previous := listLANIPv4s
	listLANIPv4s = func() []string {
		return []string{"192.168.1.20"}
	}
	t.Cleanup(func() {
		listLANIPv4s = previous
	})

	access := collectAccessURLs(config.Config{
		ListenAddr: "127.0.0.1:4318",
	})

	if access.BrowserURL != "http://127.0.0.1:4318" {
		t.Fatalf("unexpected browser URL: %s", access.BrowserURL)
	}
	if access.PhoneURL != "http://127.0.0.1:4318" {
		t.Fatalf("unexpected phone URL: %s", access.PhoneURL)
	}
	if access.HealthzURL != "http://127.0.0.1:4318/healthz" {
		t.Fatalf("unexpected healthz URL: %s", access.HealthzURL)
	}
	if len(access.ExtraLANURLs) != 0 {
		t.Fatalf("unexpected extra LAN URLs: %#v", access.ExtraLANURLs)
	}
	if access.PhoneHint == "" {
		t.Fatal("expected phone hint for loopback listen address")
	}
}
