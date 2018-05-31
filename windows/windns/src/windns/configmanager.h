#pragma once

#include "dnsconfig.h"
#include "itracesink.h"
#include <map>
#include <string>
#include <mutex>
#include <memory>
#include <functional>

//
// The ConfigManager is engineered to track the "real" DNS configuration for an adapter.
//
// The situation is somewhat complicated, because a given system may have several adapters, which
// in turn may have several configurations?
//
// Every update for every configuration is recorded, bar the ones that correspond to us
// overriding the DNS settings.
//

class ConfigManager
{
public:

	struct Mutex
	{
		Mutex(const Mutex &) = delete;
		Mutex &operator=(const Mutex &) = delete;
		Mutex(Mutex &&) = delete;
		Mutex &operator=(Mutex &&) = delete;

		Mutex(ConfigManager &manager)
			: m_manager(manager)
		{
			m_manager.lock();
		}

		~Mutex()
		{
			m_manager.unlock();
		}

		ConfigManager &m_manager;
	};

	//
	// "servers" specifies the set of servers used when overriding settings.
	// This enables filtering out the corresponding event.
	//
	ConfigManager
	(
		const std::vector<std::wstring> &servers,
		std::shared_ptr<ITraceSink> traceSink = std::make_shared<NullTraceSink>()
	);

	//
	// The ConfigManager is shared between threads.
	// Locking is managed externally for reasons of efficiency.
	//
	void lock();
	void unlock();

	//
	// Notify the ConfigManager that servers used when overriding DNS settings have changed.
	//
	void updateServers(const std::vector<std::wstring> &servers);

	//
	// Get the current set of servers used for overriding DNS settings.
	//
	const std::vector<std::wstring> &getServers() const;

	//
	// Notify the ConfigManager that a live configuration has been updated.
	//
	enum class UpdateType
	{
		WinDnsEnforced,
		External
	};

	UpdateType updateConfig(const DnsConfig &previous, const DnsConfig &target);

	//
	// Enumerate recorded configs.
	//
	bool processConfigs(std::function<bool(const DnsConfig &)> configSink);

private:

	std::mutex m_mutex;
	std::vector<std::wstring> m_servers;

	//
	// Organize configs based on their system assigned index.
	//
	std::map<uint32_t, DnsConfig> m_configs;

	std::shared_ptr<ITraceSink> m_traceSink;

	//
	// Tests, by looking at the servers, whether this is an update initied by WINDNS.
	//
	bool internalUpdate(const DnsConfig &config);
};
