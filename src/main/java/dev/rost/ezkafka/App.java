package dev.rost.ezkafka;

import com.fasterxml.jackson.databind.JsonNode;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.kafka.annotation.KafkaListener;

@SpringBootApplication
public class App {

	public static void main(String[] args) {
		SpringApplication.run(App.class, args);
	}


    @KafkaListener(topics = "ez")
    void onMessage(ConsumerRecord<String, JsonNode> message) {
        System.out.println("message = " + message);
    }
}
