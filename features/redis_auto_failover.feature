Feature: Redis auto failover
  In order to eliminate a single point of failure
  Beetle handlers should automatically switch to a new redis master in case of a redis master failure

  Background:
    Given a redis server "redis-1" exists as master
    And a redis server "redis-2" exists as slave of "redis-1"

  Scenario: Successful redis master switch
    Given a redis configuration server using redis servers "redis-1,redis-2" with clients "rc-client-1,rc-client-2" exists
    And a redis configuration client "rc-client-1" using redis servers "redis-1,redis-2" exists
    And a redis configuration client "rc-client-2" using redis servers "redis-1,redis-2" exists
    And a beetle handler using the redis-master file from "rc-client-1" exists
    And redis server "redis-1" is down
    And the retry timeout for the redis master check is reached
    Then a system notification for "redis-1" not being available should be sent
    And the role of redis server "redis-2" should be "master"
    And the redis master of "rc-client-1" should be "redis-2"
    And the redis master of "rc-client-2" should be "redis-2"
    And the redis master of the beetle handler should be "redis-2"
    And a system notification for switching from "redis-1" to "redis-2" should be sent
    Given a redis server "redis-1" exists as master
    Then the role of redis server "redis-1" should be "slave"

  Scenario: Redis master only temporarily down (no switch necessary)
    Given a redis configuration server using redis servers "redis-1,redis-2" with clients "rc-client-1,rc-client-2" exists
    And a redis configuration client "rc-client-1" using redis servers "redis-1,redis-2" exists
    And a redis configuration client "rc-client-2" using redis servers "redis-1,redis-2" exists
    And a beetle handler using the redis-master file from "rc-client-1" exists
    And redis server "redis-1" is down for less seconds than the retry timeout for the redis master check
    And the retry timeout for the redis master check is reached
    Then the role of redis server "redis-1" should be "master"
    Then the role of redis server "redis-2" should be "slave"
    And the redis master of "rc-client-1" should be "redis-1"
    And the redis master of "rc-client-2" should be "redis-1"
    And the redis master of the beetle handler should be "redis-1"

  Scenario: "client_invalidated" message not acknowledged by all redis configuration clients (no switch possible)
    Given a redis configuration server using redis servers "redis-1,redis-2" with clients "rc-client-1,rc-client-2" exists
    And a redis configuration client "rc-client-1" using redis servers "redis-1,redis-2" exists
    And redis server "redis-1" is down
    And the retry timeout for the redis master check is reached
    Then the role of redis server "redis-2" should be "slave"
    And the redis master of "rc-client-1" should be undefined

  Scenario: No redis slave available to become new master (no switch possible)
    Given a redis configuration server using redis servers "redis-1,redis-2" with clients "rc-client-1,rc-client-2" exists
    And a redis configuration client "rc-client-1" using redis servers "redis-1,redis-2" exists
    And a redis configuration client "rc-client-2" using redis servers "redis-1,redis-2" exists
    And redis server "redis-1" is down
    And redis server "redis-2" is down
    And the retry timeout for the redis master check is reached
    Then the redis master of "rc-client-1" should be "redis-1"
    And the redis master of "rc-client-2" should be "redis-1"
    And a system notification for no slave available to become new master should be sent

  Scenario: Redis configuration client joins while no redis master available
    Given redis server "redis-1" is down
    And redis server "redis-2" is down
    And an old redis master file for "rc-client-1" with master "redis-1" exists
    And a redis configuration client "rc-client-1" using redis servers "redis-1,redis-2" exists
    And the retry timeout for the redis master determination is reached
    Then the redis master of "rc-client-1" should be undefined

  Scenario: Redis configuration client joins while both redis servers are master
    Given redis server "redis-2" is master
    And an old redis master file for "rc-client-1" with master "redis-1" exists
    And a redis configuration client "rc-client-1" using redis servers "redis-1,redis-2" exists
    Then the redis master of "rc-client-1" should be "redis-1"

  Scenario: Redis configuration client joins while no redis server is master
    Given a redis server "redis-3" exists as master
    And redis server "redis-1" is slave of "redis-3"
    And redis server "redis-2" is slave of "redis-3"
    And an old redis master file for "rc-client-1" with master "redis-1" exists
    And a redis configuration client "rc-client-1" using redis servers "redis-1,redis-2" exists
    Then the redis master of "rc-client-1" should be undefined

  Scenario: Redis configuration client joins while there is a redis master but no slave
    Given a redis configuration server using redis servers "redis-1,redis-2" with clients "rc-client-1" exists
    Given redis server "redis-2" is down
    And a redis configuration client "rc-client-1" using redis servers "redis-1,redis-2" exists
    Then the redis master of "rc-client-1" should be "redis-1"

  Scenario: all "client_invalidated" message get acknowledged after the acknowledgement round failed initially
    Given a redis configuration server using redis servers "redis-1,redis-2" with clients "rc-client-1,rc-client-2" exists
    And a redis configuration client "rc-client-1" using redis servers "redis-1,redis-2" exists
    And redis server "redis-1" is down
    And the retry timeout for the redis master check is reached
    Then the role of redis server "redis-2" should be "slave"
    And the redis master of "rc-client-1" should be undefined
    And a redis configuration client "rc-client-2" using redis servers "redis-1,redis-2" exists
    And the retry timeout for the redis master check is reached
    And the role of redis server "redis-2" should be "master"
    And the redis master of "rc-client-1" should be "redis-2"
    And the redis master of "rc-client-2" should be "redis-2"
